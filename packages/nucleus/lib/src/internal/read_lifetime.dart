part of 'internal.dart';

final _emptyDisposers = List<void Function()>.empty();

class ReadLifetime implements AtomContext<dynamic> {
  ReadLifetime(this.node) : registry = node.registry;

  final AtomRegistry registry;
  final Node node;

  var _disposers = _emptyDisposers;
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
  dynamic self() => node._value;

  @override
  void set<R, W>(WritableAtom<R, W> atom, W value) {
    assert(!_disposed);
    registry.set(atom, value);
  }

  @override
  void Function() subscribe<T>(Atom<T> atom, void Function(T value) handler) =>
      registry.subscribe(atom, handler);

  @override
  void Function() subscribeWithPrevious<A>(
    Atom<A> atom,
    void Function(A? previous, A value) handler,
  ) =>
      registry.subscribeWithPrevious(atom, handler);

  @override
  Stream<A> stream<A>(Atom<A> atom) => registry.stream(atom);

  @override
  void setSelf(dynamic value) {
    assert(!_disposed);
    node.setValue(value);
  }

  @override
  void onDispose(void Function() onDispose) {
    if (_disposers == _emptyDisposers) {
      _disposers = [onDispose];
    } else {
      _disposers.add(onDispose);
    }
  }

  void dispose() {
    assert(!_disposed);
    _disposed = true;

    if (_disposers == _emptyDisposers) {
      return;
    }

    for (final f in _disposers) {
      f();
    }
    _disposers = _emptyDisposers;
  }
}
