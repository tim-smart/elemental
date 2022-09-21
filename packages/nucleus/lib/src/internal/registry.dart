part of 'internal.dart';

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
  final nodes = Expando<Node>();

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

  /// Listen to changes of an atom's state, and retrieve the latest value.
  void Function() subscribeWithValue<A>(
    Atom<A> atom,
    void Function(A? previous, A value) handler, {
    bool fireImmediately = false,
    bool checkEquality = true,
  }) {
    final node = _ensureNode(atom);

    A? previousValue;

    if (!fireImmediately) {
      previousValue = node.value;
    }

    return subscribe(atom, () {
      final nextValue = node.value;

      if (checkEquality && previousValue == nextValue) {
        return;
      }

      handler(previousValue, nextValue);
      previousValue = nextValue;
    }, fireImmediately: fireImmediately);
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
      }, fireImmediately: true);

  // Internal

  Node _ensureNode(Atom atom) => nodes[atom] ??= _createNode(atom);

  Node _createNode(Atom atom) {
    if (!atom.shouldKeepAlive) {
      _scheduler.runPostFrame(() => _maybeRemoveAtom(atom));
    }
    return Node(this, atom);
  }

  void _maybeRemoveAtom(Atom atom) {
    final node = nodes[atom];
    if (node != null && node.canBeRemoved) {
      _removeNode(node);
    }
  }

  void _scheduleNodeRemoval(Node node) {
    _scheduler.runPostFrame(() {
      if (node.canBeRemoved) {
        _removeNode(node);
      }
    });
  }

  void _removeNode(Node node) {
    assert(node.canBeRemoved);

    final parents = node.parents;

    nodes[node.atom] = null;
    node.remove();

    if (parents.isEmpty) return;
    for (final node in parents) {
      if (node.canBeRemoved) {
        _removeNode(node);
      }
    }
  }
}
