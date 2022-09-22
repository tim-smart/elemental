part of 'internal.dart';

final _emptyNodes = List<Node>.empty();

enum NodeState {
  uninitialized(waitingForValue: true),
  stale(initialized: true, waitingForValue: true),
  valid(initialized: true),
  removed(alive: false);

  const NodeState({
    this.waitingForValue = false,
    this.alive = true,
    this.initialized = false,
  });
  final bool waitingForValue;
  final bool alive;
  final bool initialized;
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
    assert(_state.alive);

    if (_state.waitingForValue) {
      _lifetime = ReadLifetime(this);

      final value = atom.$read(_lifetime!);
      if (_state.waitingForValue) {
        setValue(value);
      }

      // Removed orphaned parents
      if (previousParents != null && previousParents!.isNotEmpty) {
        for (final node in previousParents!) {
          if (node.canBeRemoved) {
            registry._scheduleNodeRemoval(node);
          }
        }
      }
    }

    return _value;
  }

  void addParent(Node node) {
    assert(_state.alive);

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
    assert(_state.alive);

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
    assert(_state == NodeState.valid);

    _state = NodeState.stale;
    disposeLifetime(parent);

    // Rebuild
    value;
  }

  void invalidateChildren() {
    assert(_state == NodeState.valid);

    if (children == _emptyNodes) {
      return;
    }

    final childNodes = children;
    final count = childNodes.length;
    children = [];

    for (var i = 0; i < count; i++) {
      final node = childNodes[i];
      node.invalidate(this);
    }
  }

  void notifyListeners() {
    assert(_state.initialized);

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
    assert(_state.alive);

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
