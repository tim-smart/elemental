import 'internal.dart';

enum NodeState {
  uninitialized,
  stale,
  valid,
  removed,
}

class Node<A> {
  Node(this._builder);

  var _state = NodeState.uninitialized;

  final NodeDepsFn<A> _builder;

  final parents = <Node>[];
  final children = <Node>[];
  final listeners = <void Function()>[];

  ReadLifetime<A>? _lifetime;

  bool get canBeRemoved => listeners.isEmpty && children.isEmpty;

  late A _value;
  A get value {
    assert(_state != NodeState.removed);

    if (_state != NodeState.valid) {
      _lifetime = ReadLifetime(_builder(
        addParent,
        setValue,
        _state == NodeState.uninitialized ? null : _value,
      ));

      final value = _lifetime!.create();
      if (_state != NodeState.valid) {
        setValue(value);
      }
    }

    return _value;
  }

  void addParent(Node node) {
    assert(_state != NodeState.removed);

    if (parents.contains(node)) {
      return;
    }
    parents.add(node);
    node.addChild(this);
  }

  void addChild(Node node) {
    assert(_state != NodeState.removed);

    if (children.contains(node)) {
      return;
    }
    children.add(node);
  }

  void setValue(A value) {
    assert(_state != NodeState.removed);

    if (_state == NodeState.uninitialized) {
      _state = NodeState.valid;
      _value = value;
      notifyListeners();
      return;
    }

    _state = NodeState.valid;
    if (value == _value) {
      return;
    }

    _value = value;
    invalidateChildren();
    notifyListeners();
  }

  void invalidate() {
    assert(_state != NodeState.removed);

    if (_state == NodeState.stale) {
      return;
    }

    dispose();
    _state = NodeState.stale;

    invalidateChildren();
  }

  void invalidateChildren() {
    assert(_state == NodeState.stale || _state == NodeState.valid);

    if (children.isEmpty) return;
    for (final node in children) {
      node.invalidate();
    }
  }

  void notifyListeners() {
    assert(_state == NodeState.valid);

    if (listeners.isEmpty) return;
    for (final f in listeners) {
      f();
    }
  }

  void dispose() {
    _lifetime?.dispose();
  }

  void remove() {
    if (_state == NodeState.removed) return;
    _state = NodeState.removed;

    dispose();

    for (final node in children) {
      node.parents.remove(this);
    }

    for (final node in parents) {
      node.children.remove(this);
    }
  }

  void Function() addListener(void Function() handler) {
    listeners.add(handler);
    return () => listeners.remove(handler);
  }
}
