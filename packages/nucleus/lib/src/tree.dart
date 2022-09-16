class Node<A> {
  Node({
    required this.value,
  });

  final A value;

  final parents = <Branch>[];
  final invalidParents = <Branch>[];

  final children = <Branch>[];

  bool get valid => invalidParents.isEmpty;

  void addParent<P>(Node<P> node) {
    final branch = Branch(node, this);

    if (parents.contains(branch) || invalidParents.contains(branch)) {
      return;
    }

    parents.add(branch);
  }

  void addChild<C>(Node<C> node) {
    final branch = Branch(this, node);

    if (children.contains(branch)) {
      return;
    }

    children.add(branch);
  }
}

class Branch<P, C> {
  Branch(this.from, this.to);

  final Node<P> from;
  final Node<C> to;
  var valid = true;

  void validate() {
    if (valid) return;
    valid = true;

    to.invalidParents.remove(this);
    to.parents.add(this);
  }

  void invalidate() {
    if (!valid) return;
    valid = false;

    to.parents.remove(this);
    to.invalidParents.add(this);
  }

  void remove() {
    to.parents
  }

  @override
  operator ==(Object? other) =>
      other is Branch && other.from == from && other.to == to;

  @override
  int get hashCode => from.hashCode ^ to.hashCode;
}
