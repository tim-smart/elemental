import 'dart:async';
import 'dart:collection';

import 'package:nucleus/nucleus.dart';

import 'internal.dart';

class AtomRegistry {
  final scheduler = Scheduler();
  final nodes = HashMap<Atom, Node>();

  A get<A>(Atom<A> atom) => _ensureNode(atom).value as A;

  void set<R, W>(WritableAtom<R, W> atom, W value) {
    final node = _ensureNode(atom);
    atom.write(get, set, node.setValue, value);
  }

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
      if (!atom.shouldKeepAlive && node.canBeRemoved) {
        scheduler.runPostFrame(() => _maybeRemoveNode(atom));
      }
    };
  }

  Future<A> use<A>(Atom atom, FutureOr<A> Function() f) async {
    final remove = subscribe(atom, () {});

    try {
      return await f();
    } finally {
      remove();
    }
  }

  void Function() mount(Atom atom) => subscribe(atom, () {
        get(atom);
      });

  // Internal

  Node _ensureNode(Atom atom) => nodes.putIfAbsent(atom, () {
        if (!atom.shouldKeepAlive) {
          scheduler.runPostFrame(() => _maybeRemoveNode(atom));
        }
        return Node(_createNodeDepsFn(atom));
      });

  void _maybeRemoveNode(Atom atom) {
    final node = nodes[atom];
    if (node == null || !node.canBeRemoved) {
      return;
    }

    nodes.remove(atom);
    node.remove();
  }

  NodeDepsFn _createNodeDepsFn(Atom atom) =>
      (addParent, setSelf, previousValue) => (onDispose, assertNotDisposed) {
            T getAndRegister<T>(Atom<T> atom) {
              final node = _ensureNode(atom);
              addParent(node);
              return node.value as T;
            }

            return () => atom.$read(
                  get: getAndRegister,
                  set: set,
                  onDispose: onDispose,
                  setSelf: setSelf,
                  previousValue: previousValue,
                  assertNotDisposed: assertNotDisposed,
                );
          };
}
