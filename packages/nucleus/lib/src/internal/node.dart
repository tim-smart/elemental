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

  Branch? parent;
  Branch? previousParent;
  Branch? child;
  Listener? listener;

  ReadLifetime? _lifetime;

  bool get canBeRemoved =>
      !atom.shouldKeepAlive &&
      listener == null &&
      state != NodeState.removed &&
      child == null;

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
      if (previousParent != null) {
        var branch = previousParent;
        while (branch != null) {
          if (parent == null || !parent!.contains(branch.node)) {
            branch.node.removeChild(this);
            if (branch.node.canBeRemoved) {
              registry._scheduleNodeRemoval(branch.node);
            }
          }

          branch = branch.to;
        }

        previousParent = null;
      }
    }

    return _value;
  }

  void addParent(Node node) {
    assert(state.alive);

    parent = Branch(
      node: node,
      to: parent,
    );

    // Add to parent children
    if (node.child == null || !node.child!.contains(this)) {
      node.child = Branch(
        node: this,
        to: node.child,
      );
    }
  }

  void removeChild(Node node) {
    if (child?.node == node) {
      child = child?.to;
      child?.from = null;
    } else {
      child?.remove(node);
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

    if (child == null) {
      return;
    }

    var branch = child;
    child = null;

    while (branch != null) {
      branch.node.invalidate(this);
      branch = branch.to;
    }
  }

  void notifyListeners() {
    assert(state.initialized, state.toString());

    if (listener == null) {
      return;
    }

    var next = listener;
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

    previousParent = parent;
    parent = null;
  }

  void remove() {
    assert(canBeRemoved);
    assert(state.alive);

    state = NodeState.removed;

    if (_lifetime != null) {
      disposeLifetime();

      if (previousParent != null) {
        var branch = previousParent;
        while (branch != null) {
          branch.node.removeChild(this);

          if (branch.node.canBeRemoved) {
            registry._removeNode(branch.node);
          }

          branch = branch.to;
        }

        previousParent = null;
      }
    }
  }

  void Function() addListener(void Function() handler) {
    final l = Listener(
      fn: handler,
      next: listener,
    );
    listener = l;

    return () {
      if (listener == l) {
        listener = l.next;
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

class Branch {
  Branch({
    required this.node,
    this.to,
  }) {
    to?.from = this;
  }

  final Node node;
  Branch? from;
  Branch? to;

  bool contains(Node node) {
    Branch? branch = this;
    while (branch != null) {
      if (branch.node == node) {
        return true;
      }
      branch = branch.to;
    }
    return false;
  }

  void remove(Node node) {
    Branch? branch = this;
    while (branch != null) {
      if (branch.node == node) {
        branch.from?.to = branch.to;
        branch.to?.from = branch.from;
        break;
      }

      branch = branch.to;
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
