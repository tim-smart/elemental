import 'package:nucleus/nucleus.dart';

import 'internal.dart';

final _emptyNodes = List<Node>.empty();

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

  var parents = _emptyNodes;
  List<Node>? previousParents;
  var children = _emptyNodes;
  final listeners = <void Function()>[];

  ReadLifetime? _lifetime;

  bool get canBeRemoved =>
      !atom.shouldKeepAlive &&
      _state != NodeState.removed &&
      (children == _emptyNodes || children.isEmpty) &&
      listeners.isEmpty;

  late dynamic _value;
  dynamic get value {
    assert(_state != NodeState.removed);

    if (_state != NodeState.valid) {
      _lifetime = ReadLifetime(_builder);

      final value = _lifetime!.create();
      if (_state != NodeState.valid) {
        setValue(value);
      }

      // Removed orphaned parents
      if (previousParents != null && previousParents!.isNotEmpty) {
        for (final node in previousParents!) {
          if (node.canBeRemoved) {
            _removeNode(node);
          }
        }
      }
    }

    return _value;
  }

  dynamic _getValue() => _state == NodeState.uninitialized ? null : _value;

  void addParent(Node node) {
    assert(_state != NodeState.removed);

    if (parents == _emptyNodes) {
      parents = [node];
    } else {
      parents.add(node);
      previousParents?.remove(node);
    }

    // Add to parent children
    if (node.children == _emptyNodes) {
      node.children = [this];
    } else if (!node.children.contains(this)) {
      node.children.add(this);
    }
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
    invalidateChildren(parent);
    notifyListeners();
  }

  void invalidateChildren([Node? parent]) {
    assert(_state == NodeState.stale || _state == NodeState.valid);

    if (children == _emptyNodes) {
      return;
    }

    final childNodes = children;
    final count = childNodes.length;
    children = [];

    if (parent != null && count == 1 && childNodes[0] == parent) {
      return;
    }

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
    if (_lifetime != null) {
      _lifetime!.dispose();
      _lifetime = null;
    }

    if (parents == _emptyNodes) {
      return;
    }

    previousParents = parents;
    parents = [];
    final count = previousParents!.length;

    if (count == 0 || (count == 1 && previousParents![0] == parent)) {
      return;
    }

    for (var i = 0; i < count; i++) {
      final node = previousParents![i];
      if (node == parent) continue;

      node.children.remove(this);

      if (node.canBeRemoved) {
        _removeNode(node);
      }
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
