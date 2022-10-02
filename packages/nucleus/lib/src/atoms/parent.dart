part of '../atoms.dart';

/// See [atomWithParent].
class AtomWithParentBase<A, Parent extends Atom> extends Atom<A> {
  AtomWithParentBase(this.parent, this.reader);

  /// The parent [Atom].
  final Parent parent;
  final A Function(AtomContext<A>, Parent parent) reader;

  @override
  A $read(AtomContext<A> ctx) => reader(ctx, parent);
}

class AtomWithParent<A, Parent extends Atom>
    extends AtomWithParentBase<A, Parent>
    with
        AtomConfigMixin<AtomWithParent<A, Parent>>,
        RefreshableAtomMixin<RefreshableAtomWithParent<A, Parent>> {
  AtomWithParent(super.parent, super.reader);

  @override
  RefreshableAtomWithParent<A, Parent> refreshable() =>
      RefreshableAtomWithParent(parent, reader);
}

/// See [atomWithParent].
class RefreshableAtomWithParent<A, Parent extends Atom> = AtomWithParentBase<A,
        Parent>
    with AtomConfigMixin<RefreshableAtomWithParent<A, Parent>>, RefreshableAtom;

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
