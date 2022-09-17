import 'package:nucleus/nucleus.dart';

import 'internal.dart';

enum NodeState {
  uninitialized,
  stale,
  valid,
  removed,
}

class Node {
  Node(this.atom, this._builder);

  final Atom atom;
  var _state = NodeState.uninitialized;
  NodeState get state => _state;

  final NodeDepsFn _builder;

  var parents = <Node>[];
  var children = <Node>[];
  final listeners = <void Function()>[];

  ReadLifetime? _lifetime;

  bool get canBeRemoved =>
      !atom.shouldKeepAlive &&
      _state != NodeState.removed &&
      listeners.isEmpty &&
      children.isEmpty;

  late Object? _value;
  Object? get value {
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

  void setValue(Object? value) {
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

  void invalidate(Node parent) {
    assert(_state == NodeState.valid, _state.toString());
    _state = NodeState.stale;

    dispose(parent);
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

  void dispose([Node? parent]) {
    _lifetime?.dispose();

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
    dispose();
  }

  void Function() addListener(void Function() handler) {
    listeners.add(handler);
    return () => listeners.remove(handler);
  }
}
