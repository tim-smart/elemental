import 'package:nucleus/nucleus.dart';

import 'internal.dart';

enum NodeState {
  uninitialized,
  stale,
  valid,
  removed,
}

class Node {
  Node(this.atom, NodeDepsFn builder, this._removeNode) {
    _builder = builder(addParent, setValue, _getValue);
  }

  final Atom atom;
  late final LifetimeDepsFn _builder;
  final void Function(Node node) _removeNode;

  var _state = NodeState.uninitialized;
  NodeState get state => _state;

  var parents = <Node>[];
  var children = <Node>[];
  final listeners = <void Function()>[];

  ReadLifetime? _lifetime;

  bool get canBeRemoved =>
      !atom.shouldKeepAlive &&
      _state != NodeState.removed &&
      listeners.isEmpty &&
      children.isEmpty;

  late dynamic _value;
  dynamic get value {
    assert(_state != NodeState.removed);

    if (_state != NodeState.valid) {
      _lifetime = ReadLifetime(_builder);

      final value = _lifetime!.create();
      if (_state != NodeState.valid) {
        setValue(value);
      }
    }

    return _value;
  }

  dynamic _getValue() => _state == NodeState.uninitialized ? null : _value;

  void addParent(Node node) {
    assert(_state != NodeState.removed);

    parents.add(node);
    node.addChild(this);
  }

  void addChild(Node node) {
    assert(_state != NodeState.removed);

    if (children.isNotEmpty && children.contains(node)) {
      return;
    }
    children.add(node);
  }

  void setValue(dynamic value) {
    assert(_state != NodeState.removed);

    if (_state == NodeState.uninitialized) {
      _state = NodeState.valid;
      _value = value;
      notifyListeners();
      return;
    }

    final previousState = _state;
    _state = NodeState.valid;
    if (value == _value) {
      return;
    }

    _value = value;

    if (previousState == NodeState.valid) {
      invalidateChildren();
      notifyListeners();
    }
  }

  void invalidate(Node parent) {
    assert(_state == NodeState.valid, _state.toString());
    _state = NodeState.stale;

    disposeLifetime(parent);
    invalidateChildren();
    notifyListeners();
  }

  void invalidateChildren() {
    assert(_state == NodeState.stale || _state == NodeState.valid);

    if (children.isEmpty) {
      return;
    }

    final childNodes = children;
    final count = childNodes.length;
    children = [];

    for (var i = 0; i < count; i++) {
      final node = childNodes[i];
      if (node._state == NodeState.stale) continue;
      node.invalidate(this);
    }
  }

  void notifyListeners() {
    assert(_state == NodeState.valid || _state == NodeState.stale);

    if (listeners.isEmpty) {
      return;
    }

    final count = listeners.length;
    for (var i = 0; i < count; i++) {
      listeners[i]();
    }
  }

  void disposeLifetime([Node? parent]) {
    _lifetime?.dispose();
    _lifetime = null;

    if (parents.isNotEmpty) {
      final count = parents.length;
      for (var i = 0; i < count; i++) {
        final node = parents[i];
        if (node == parent) continue;

        node.children.remove(this);
        if (node.canBeRemoved) {
          _removeNode(node);
        }
      }
      parents = [];
    }
  }

  void remove() {
    assert(canBeRemoved);
    assert(_state != NodeState.removed);

    _state = NodeState.removed;

    if (_lifetime != null) {
      disposeLifetime();
    }
  }

  void Function() addListener(void Function() handler) {
    listeners.add(handler);
    return () => listeners.remove(handler);
  }

  @override
  String toString() =>
      "Node(atom: $atom, _state: $_state, canBeRemoved: $canBeRemoved, value: $value)";
}
