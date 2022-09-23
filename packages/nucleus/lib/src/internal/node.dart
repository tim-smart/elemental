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

  var state = NodeState.uninitialized;

  var parents = _emptyNodes;
  List<Node>? previousParents;
  var children = _emptyNodes;
  final listeners = <void Function()>[];
  var _listenerCount = 0;

  ReadLifetime? _lifetime;

  bool get canBeRemoved =>
      !atom.shouldKeepAlive &&
      _listenerCount == 0 &&
      state != NodeState.removed &&
      (children == _emptyNodes || children.isEmpty);

  dynamic _value;
  dynamic get value {
    assert(state.alive);

    if (state.waitingForValue) {
      _lifetime = ReadLifetime(this);

      final value = atom.$read(_lifetime!);
      if (state.waitingForValue) {
        setValue(value);
      }

      // Removed orphaned parents
      if (previousParents != null && previousParents!.isNotEmpty) {
        for (final node in previousParents!) {
          node.children.remove(this);

          if (node.canBeRemoved) {
            registry._scheduleNodeRemoval(node);
          }
        }
      }
    }

    return _value;
  }

  void addParent(Node node) {
    assert(state.alive);

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
    assert(state.alive);

    if (state == NodeState.uninitialized) {
      state = NodeState.valid;
      _value = value;
      notifyListeners();
      return;
    }

    state = NodeState.valid;
    if (value == _value) {
      return;
    }

    _value = value;

    invalidateChildren();
    notifyListeners();
  }

  void invalidate(Node parent) {
    assert(state == NodeState.valid);

    state = NodeState.stale;
    disposeLifetime();

    // Rebuild
    value;
  }

  void invalidateChildren() {
    assert(state == NodeState.valid);

    if (children == _emptyNodes) {
      return;
    }

    final childNodes = children;
    final count = childNodes.length;
    children = [];

    for (var i = 0; i < count; i++) {
      childNodes[i].invalidate(this);
    }
  }

  void notifyListeners() {
    assert(state.initialized, state.toString());

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

  void disposeLifetime() {
    if (_lifetime != null) {
      _lifetime!.dispose();
      _lifetime = null;
    }

    if (parents == _emptyNodes) {
      return;
    }

    previousParents = parents;
    parents = [];
  }

  void remove() {
    assert(canBeRemoved);
    assert(state.alive);

    state = NodeState.removed;

    if (_lifetime != null) {
      disposeLifetime();

      if (previousParents != null && previousParents!.isNotEmpty) {
        for (final node in previousParents!) {
          node.children.remove(this);

          if (node.canBeRemoved) {
            registry._removeNode(node);
          }
        }
      }
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
      "Node(atom: $atom, _state: $state, canBeRemoved: $canBeRemoved, value: $value)";
}
