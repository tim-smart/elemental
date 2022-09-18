import 'package:nucleus/nucleus.dart';

import 'internal.dart';

enum NodeState {
  uninitialized,
  stale,
  valid,
  removed,
}

class Node {
  Node(this.atom, NodeDepsFn builder) {
    _builder = builder(addParent, setValue, _getValue);
  }

  final Atom atom;
  var _state = NodeState.uninitialized;
  NodeState get state => _state;

  late final LifetimeDepsFn _builder;

  var parents = <Node>[];
  var children = <Node>[];
  final listeners = <void Function()>[];

  ReadLifetime? _lifetime;

  bool get canBeRemoved =>
      !atom.shouldKeepAlive && listeners.isEmpty && children.isEmpty;

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

    if (children.contains(node)) {
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

    if (children.isEmpty) return;

    final childNodes = children;
    children = [];

    for (final node in childNodes) {
      if (node._state == NodeState.stale) continue;
      node.invalidate(this);
    }
  }

  void notifyListeners() {
    assert(_state == NodeState.valid || _state == NodeState.stale);

    if (listeners.isEmpty) return;
    for (final f in listeners) {
      f();
    }
  }

  void disposeLifetime([Node? parent]) {
    _lifetime?.dispose();
    _lifetime = null;

    if (parents.isNotEmpty) {
      for (final node in parents) {
        if (node == parent) continue;
        node.children.remove(this);
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
