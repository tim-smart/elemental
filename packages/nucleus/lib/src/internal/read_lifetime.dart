part of 'internal.dart';

class ReadLifetime implements AtomContext<dynamic> {
  ReadLifetime(this.node) : registry = node.registry;

  final AtomRegistry registry;
  final Node node;

  Listener? _disposers;
  var _disposed = false;

  @override
  T call<T>(Atom<T> atom) {
    final parent = registry._ensureNode(atom);
    node.addParent(parent);
    return parent.value as T;
  }

  @override
  T get<T>(Atom<T> atom) {
    final parent = registry._ensureNode(atom);
    node.addParent(parent);
    return parent.value as T;
  }

  @override
  R once<R>(Atom<R> atom) => registry.get(atom);

  @override
  dynamic self() => node._value;

  @override
  void set<R, W>(WritableAtomBase<R, W> atom, W value) {
    assert(!_disposed);
    registry.set(atom, value);
  }

  @override
  void refresh(RefreshableAtom atom) {
    assert(!_disposed);
    registry.refresh(atom);
  }

  @override
  void refreshSelf() {
    assert(!_disposed);
    assert(node.state == NodeState.valid);
    node.invalidate();
  }

  @override
  void Function() subscribe<T>(
    Atom<T> atom,
    void Function(T value) handler, {
    bool fireImmediately = false,
  }) =>
      registry.subscribe(atom, handler, fireImmediately: fireImmediately);

  @override
  void Function() subscribeWithPrevious<A>(
    Atom<A> atom,
    void Function(A? previous, A value) handler, {
    bool fireImmediately = false,
  }) =>
      registry.subscribeWithPrevious(
        atom,
        handler,
        fireImmediately: fireImmediately,
      );

  @override
  Stream<A> stream<A>(Atom<A> atom) => registry.stream(atom);

  @override
  void setSelf(dynamic value) {
    assert(!_disposed);
    node.setValue(value);
  }

  @override
  void onDispose(void Function() onDispose) {
    _disposers = Listener(
      fn: onDispose,
      next: _disposers,
    );
  }

  void dispose() {
    assert(!_disposed);
    _disposed = true;

    if (_disposers == null) {
      return;
    }

    var next = _disposers;
    while (next != null) {
      next.fn();
      next = next.next;
    }
    _disposers = null;
  }
}
