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
  void set<R, W>(WritableAtom<R, W> atom, W value) =>
      atom.write(get, set, _ensureNode(atom).setValue, value);

  /// Listen to changes of an atom's state.
  ///
  /// Call [get] to retrieve the latest value after the [handler] is called.
  void Function() subscribe(
    Atom atom,
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
        _scheduler.runPostFrame(() {
          if (!node.canBeRemoved) return;
          _removeNode(node);
        });
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

  /// Build a tree with the current node state. For debugging only.
  Map<K, dynamic> buildTree<K>(K Function(Node) key) {
    Map<K, dynamic> getChildren(Node node) => node.children.fold(
          {},
          (acc, node) => {
            ...acc,
            key(node): getChildren(node),
          },
        );

    return nodes.values.where((n) => n.parents.isEmpty).fold(
      {},
      (acc, node) => {
        ...acc,
        key(node): getChildren(node),
      },
    );
  }

  /// Get a tree of the current nodes. For debugging only.
  Map<Node, dynamic> get nodeTree => buildTree((n) => n);

  /// Get a tree of the current atoms. For debugging only.
  Map<Atom, dynamic> get atomTree => buildTree((n) => n.atom);

  // Internal

  Node _ensureNode(Atom atom) => nodes.putIfAbsent(atom, () {
        if (!atom.shouldKeepAlive) {
          _scheduler.runPostFrame(() => _maybeRemoveAtom(atom));
        }
        return Node(atom, _createNodeDepsFn(atom), _removeNode);
      });

  void _maybeRemoveAtom(Atom atom) {
    if (nodes.containsKey(atom)) {
      final node = nodes[atom]!;
      if (node.canBeRemoved) {
        _removeNode(node);
      }
    }
  }

  void _removeNode(Node node) {
    assert(node.canBeRemoved);

    final parents = node.parents;

    nodes.remove(node.atom);
    node.remove();

    if (parents.isEmpty) return;
    for (final node in parents) {
      if (node.canBeRemoved) {
        _removeNode(node);
      }
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
              subscribe: subscribe,
              previousValue: previousValue(),
              assertNotDisposed: assertNotDisposed,
            );
      };
}
