part of 'internal.dart';

final _emptyDisposers = List<void Function()>.empty();

class ReadLifetime implements AtomContext<dynamic> {
  ReadLifetime(this.node) : registry = node.registry;

  final AtomRegistry registry;
  final Node node;

  var _disposers = _emptyDisposers;
  var _disposed = false;
  var _setSelf = false;

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
  void set<R, W>(WritableAtom<R, W> atom, W value) {
    assert(!_disposed);
    registry.set(atom, value);
  }

  @override
  void Function() subscribe(Atom atom, void Function() handler) =>
      registry.subscribe(atom, handler);

  @override
  void setSelf(dynamic value) {
    assert(!_disposed);
    _setSelf = true;
    node.setValue(value);
  }

  @override
  dynamic get previousValue {
    assert(!_setSelf);
    return node._value;
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
