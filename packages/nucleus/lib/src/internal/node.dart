part of 'internal.dart';

final _emptyNodes = List<Node>.empty();

enum NodeState {
  uninitialized,
  stale,
  valid,
  removed,
}

class Node {
  Node(this.registry, this.atom);

  final AtomRegistry registry;
  final Atom atom;

  var _state = NodeState.uninitialized;
  NodeState get state => _state;

  var parents = _emptyNodes;
  List<Node>? previousParents;
  var children = _emptyNodes;
  final listeners = <void Function()>[];
  var _listenerCount = 0;

  ReadLifetime? _lifetime;

  bool get canBeRemoved =>
      !atom.shouldKeepAlive &&
      _listenerCount == 0 &&
      _state != NodeState.removed &&
      (children == _emptyNodes || children.isEmpty);

  dynamic _value;
  dynamic get value {
    assert(_state != NodeState.removed);

    if (_state != NodeState.valid) {
      _lifetime = ReadLifetime(this);

      final value = atom.$read(_lifetime!);
      if (_state != NodeState.valid) {
        setValue(value);
      }

      // Removed orphaned parents
      if (previousParents != null && previousParents!.isNotEmpty) {
        for (final node in previousParents!) {
          if (node.canBeRemoved) {
            registry._removeNode(node);
          }
        }
      }
    }

    return _value;
  }

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

    if (children == _emptyNodes) {
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

    if (_listenerCount == 0) {
      return;
    } else if (_listenerCount == 1) {
      listeners[0]();
      return;
    }

    for (var i = 0; i < _listenerCount; i++) {
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

    if (count == 1 && previousParents![0] == parent) {
      return;
    }

    for (var i = 0; i < count; i++) {
      final node = previousParents![i];
      if (node == parent) continue;

      node.children.remove(this);

      if (node.canBeRemoved) {
        registry._removeNode(node);
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
    _listenerCount++;
    return () {
      listeners.remove(handler);
      _listenerCount--;
    };
  }

  @override
  String toString() =>
      "Node(atom: $atom, _state: $_state, canBeRemoved: $canBeRemoved, value: $value)";
}
