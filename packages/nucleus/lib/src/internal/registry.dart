import 'dart:async';
import 'dart:collection';

import 'package:nucleus/nucleus.dart';

import 'internal.dart';

/// Responsible for mapping atom's to their state.
///
/// Each atom corresponds to a [Node], which contains the current state for that
/// atom.
class AtomRegistry {
  AtomRegistry({
    List<AtomInitialValue> initialValues = const [],
  }) {
    for (final iv in initialValues) {
      final node = _ensureNode(iv.atom);
      node.setValue(iv.value);
    }
  }

  final _scheduler = Scheduler();

  /// The state map, where each atom has a corresponding [Node].
  final nodes = HashMap<Atom, Node>();

  /// Retrieve the state for the given [Atom], creating or rebuilding it when
  /// required.
  A get<A>(Atom<A> atom) => _ensureNode(atom).value as A;

  /// Set the state of a [WritableAtom].
  void set<R, W>(WritableAtom<R, W> atom, W value) {
    final node = _ensureNode(atom);
    atom.write(get, set, node.setValue, value);
  }

  /// Listen to changes of an atom's state.
  ///
  /// Call [get] to retrieve the latest value after the [handler] is called.
  void Function() subscribe<A>(
    Atom<A> atom,
    void Function() handler, {
    bool fireImmediately = false,
  }) {
    final node = _ensureNode(atom);

    // Trigger a read
    node.value;

    final remove = node.addListener(handler);

    if (fireImmediately) {
      handler();
    }

    return () {
      remove();
      if (node.canBeRemoved) {
        _scheduler.runPostFrame(() => _maybeRemoveNode(node));
      }
    };
  }

  /// Listen to an [atom], run the given [fn] (which can return a [Future]),
  /// then remove the listener once the [fn] is complete.
  Future<A> use<A>(Atom atom, FutureOr<A> Function() fn) async {
    final remove = subscribe(atom, () {});

    try {
      return await fn();
    } finally {
      remove();
    }
  }

  /// Listen to an [atom], but don't register a handler function.
  ///
  /// Returns a function which 'unmounts' the [atom].
  void Function() mount(Atom atom) => subscribe(atom, () {
        get(atom);
      });

  // Internal

  Node _ensureNode(Atom atom) => nodes.putIfAbsent(atom, () {
        if (!atom.shouldKeepAlive) {
          _scheduler.runPostFrame(() => _maybeRemoveAtom(atom));
        }
        return Node(atom, _createNodeDepsFn(atom));
      });

  void _maybeRemoveAtom(Atom atom) {
    final node = nodes[atom];
    if (node == null) return;
    _maybeRemoveNode(node);
  }

  void _maybeRemoveNode(Node node) {
    if (!node.canBeRemoved) return;

    final parents = node.parents;

    nodes.remove(node.atom);
    node.remove();

    if (parents.isEmpty) return;
    for (final node in parents) {
      _maybeRemoveNode(node);
    }
  }

  NodeDepsFn _createNodeDepsFn(Atom atom) =>
      (addParent, setSelf, previousValue) {
        T getAndRegister<T>(Atom<T> atom) {
          final node = _ensureNode(atom);
          addParent(node);
          return node.value as T;
        }

        return (onDispose, assertNotDisposed) => atom.$read(
              get: getAndRegister,
              set: set,
              onDispose: onDispose,
              setSelf: setSelf,
              previousValue: previousValue(),
              assertNotDisposed: assertNotDisposed,
            );
      };
}
