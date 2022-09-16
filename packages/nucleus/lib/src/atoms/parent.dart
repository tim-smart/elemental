import 'package:nucleus/nucleus.dart';

class AtomWithParent<A, Parent extends Atom> extends Atom<A> {
  AtomWithParent(this.parent, this._reader);

  final Parent parent;
  final A Function(AtomContext<A>, Parent parent) _reader;

  @override
  void keepAlive() {
    parent.keepAlive();
    super.keepAlive();
  }

  @override
  A read(AtomContext<A> _) => _reader(_, parent);
}

AtomWithParent<A, Parent> atomWithParent<A, Parent extends Atom>(
  Parent parent,
  A Function(AtomContext<A> get, Parent parent) create,
) =>
    AtomWithParent(parent, create);
