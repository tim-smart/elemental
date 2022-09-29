part of '../atoms.dart';

/// See [atomWithParent].
class AtomWithParent<A, Parent extends Atom> extends Atom<A> {
  AtomWithParent(this.parent, this._reader);

  /// The parent [Atom].
  final Parent parent;
  final A Function(AtomContext<A>, Parent parent) _reader;

  @override
  void keepAlive() {
    parent.keepAlive();
    super.keepAlive();
  }

  @override
  void refreshable() {
    parent.refreshable();
  }

  @override
  A $read(AtomContext<A> ctx) => _reader(ctx, parent);

  @override
  void $refresh(void Function(Atom atom) refresh) => refresh(parent);
}

/// Create an [Atom] that is linked to a parent [Atom].
///
/// Can be used to tie a state to the thing that generates it.
///
/// I.e the parent could be a [ValueNotifier<T>] and the child would be the
/// value it emits, of type `T`. It would be represented by
/// [AtomWithParent<T, Atom<ValueNotifier<T>>>].
///
/// See [futureAtom] and [streamAtom] for examples.
AtomWithParent<A, Parent> atomWithParent<A, Parent extends Atom>(
  Parent parent,
  A Function(AtomContext<A> get, Parent parent) create,
) =>
    AtomWithParent(parent, create);
