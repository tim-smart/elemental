part of 'internal.dart';

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

  Relation? parents;
  Relation? children;
  Listener? listeners;

  ReadLifetime? _lifetime;

  bool get canBeRemoved =>
      !atom.shouldKeepAlive &&
      listeners == null &&
      children == null &&
      state != NodeState.removed;

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
      if (parents != null) {
        var relation = parents;

        while (relation != null) {
          if (relation.valid == false) {
            removeParent(relation);
          }

          relation = relation.next;
        }
      }
    }

    return _value;
  }

  void addParent(Node node) {
    assert(state.alive);

    if (parents?.findAndValidate(node) == true) {
      return;
    }

    parents = Relation(
      node: node,
      next: parents,
    );

    // Add to parent children
    node.children = Relation(
      node: this,
      next: node.children,
    );
  }

  void removeParent(Relation relation) {
    assert(relation.valid == false);

    if (parents == relation) {
      parents = relation.next;
      parents!.previous = null;
    } else {
      relation.previous!.next = relation.next;
      relation.next?.previous = relation.previous;
    }

    relation.node.removeChild(this);

    if (relation.node.canBeRemoved) {
      registry._scheduleNodeRemoval(relation.node);
    }
  }

  void removeChild(Node node) {
    if (children?.node == node) {
      children = children!.next;
      children?.previous = null;
    } else {
      children?.remove(node);
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

  void invalidate() {
    assert(state.alive);

    if (state == NodeState.valid) {
      state = NodeState.stale;
      disposeLifetime();
    }

    // Rebuild
    value;
  }

  void invalidateChildren() {
    assert(state == NodeState.valid);

    if (children == null) {
      return;
    }

    var relation = children;
    while (relation != null) {
      relation.node.invalidate();
      relation = relation.next;
    }
  }

  void notifyListeners() {
    assert(state.initialized, state.toString());

    if (listeners == null) {
      return;
    }

    var next = listeners;
    while (next != null) {
      next.fn();
      next = next.next;
    }
  }

  void disposeLifetime() {
    if (_lifetime != null) {
      _lifetime!.dispose();
      _lifetime = null;
    }

    parents?.invalidateAll();
  }

  void remove() {
    assert(canBeRemoved);

    state = NodeState.removed;

    if (_lifetime != null) {
      disposeLifetime();
    }

    if (parents == null) {
      return;
    }

    var relation = parents;
    parents = null;

    while (relation != null) {
      relation.node.removeChild(this);
      if (relation.node.canBeRemoved) {
        registry._removeNode(relation.node);
      }

      relation = relation.next;
    }
  }

  void Function() addListener(void Function() handler) {
    final l = Listener(
      fn: handler,
      next: listeners,
    );
    listeners = l;

    return () {
      if (listeners == l) {
        listeners = l.next;
        l.next?.previous = null;
      } else {
        l.previous!.next = l.next;
        l.next?.previous = l.previous;
      }
    };
  }

  @override
  String toString() =>
      "Node(atom: $atom, _state: $state, canBeRemoved: $canBeRemoved, value: $value)";
}

class Relation {
  Relation({
    required this.node,
    this.next,
  }) {
    next?.previous = this;
  }

  final Node node;
  Relation? previous;
  Relation? next;

  var valid = true;

  bool findAndValidate(Node node) {
    Relation? relation = this;
    while (relation != null) {
      if (relation.node == node) {
        relation.valid = true;
        return true;
      }
      relation = relation.next;
    }
    return false;
  }

  void remove(Node node) {
    Relation? relation = this;
    while (relation != null) {
      if (relation.node == node) {
        relation.previous?.next = relation.next;
        relation.next?.previous = relation.previous;
        break;
      }

      relation = relation.next;
    }
  }

  void invalidateAll() {
    Relation? relation = this;
    while (relation != null) {
      relation.valid = false;
      relation = relation.next;
    }
  }
}

class Listener {
  Listener({
    required this.fn,
    this.next,
  }) {
    next?.previous = this;
  }

  final void Function() fn;
  Listener? previous;
  Listener? next;
}
