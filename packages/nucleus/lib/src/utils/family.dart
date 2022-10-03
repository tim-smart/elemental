import 'dart:collection';

import 'package:nucleus/nucleus.dart';

/// Create a family factory function, for indexing similar atoms with the
/// [Arg] type.
///
/// ```dart
/// final userAtom = atomFamily((int id) => atom((get) => get(listOfUsers).getById(id)));
///
/// // To get an atom that points to user with id 123
/// final user123Atom = userAtom(123);
/// ```
A Function(Arg arg) atomFamily<A extends Atom, Arg>(
  A Function(Arg arg) create,
) {
  final atoms = HashMap<Arg, A>();
  return (arg) => atoms.putIfAbsent(arg, () => create(arg));
}

/// Alternate version of [atomFamily] that holds a weak reference to each child.
A Function(Arg arg) weakAtomFamily<A extends Atom, Arg>(
  A Function(Arg arg) create,
) {
  final atoms = HashMap<Arg, WeakReference<A>>();

  return (arg) {
    final atom = atoms[arg]?.target;
    if (atom != null) {
      return atom;
    }

    final newAtom = create(arg);
    atoms[arg] = WeakReference(newAtom);
    return newAtom;
  };
}

class FamilyArg2<A, B> {
  const FamilyArg2(this.first, this.second);
  final A first;
  final B second;

  @override
  operator ==(other) =>
      other is FamilyArg2<A, B> &&
      other.first == first &&
      other.second == second;

  @override
  int get hashCode => Object.hash(runtimeType, first, second);
}

class FamilyArg3<A, B, C> {
  const FamilyArg3(this.first, this.second, this.third);
  final A first;
  final B second;
  final C third;

  @override
  operator ==(other) =>
      other is FamilyArg3<A, B, C> &&
      other.first == first &&
      other.second == second &&
      other.third == third;

  @override
  int get hashCode => Object.hash(runtimeType, first, second, third);
}

/// A two argument variant of [atomFamily].
A Function(Arg1 a, Arg2 b) atomFamily2<Arg1, Arg2, A extends Atom>(
  A Function(Arg1 a, Arg2 b) create,
) {
  final family =
      atomFamily((FamilyArg2<Arg1, Arg2> t) => create(t.first, t.second));

  return (a, b) => family(FamilyArg2(a, b));
}

/// A three argument variant of [atomFamily].
A Function(Arg1 a, Arg2 b, Arg3 c)
    atomFamily3<Arg1, Arg2, Arg3, A extends Atom>(
  A Function(Arg1 a, Arg2 b, Arg3 c) create,
) {
  final family = atomFamily(
      (FamilyArg3<Arg1, Arg2, Arg3> t) => create(t.first, t.second, t.third));

  return (a, b, c) => family(FamilyArg3(a, b, c));
}

/// A two argument variant of [weakAtomFamily].
A Function(Arg1 a, Arg2 b) weakAtomFamily2<Arg1, Arg2, A extends Atom>(
  A Function(Arg1 a, Arg2 b) create,
) {
  final family =
      weakAtomFamily((FamilyArg2<Arg1, Arg2> t) => create(t.first, t.second));

  return (a, b) => family(FamilyArg2(a, b));
}

/// A three argument variant of [weakAtomFamily].
A Function(Arg1 a, Arg2 b, Arg3 c)
    weakAtomFamily3<Arg1, Arg2, Arg3, A extends Atom>(
  A Function(Arg1 a, Arg2 b, Arg3 c) create,
) {
  final family = weakAtomFamily(
      (FamilyArg3<Arg1, Arg2, Arg3> t) => create(t.first, t.second, t.third));

  return (a, b, c) => family(FamilyArg3(a, b, c));
}
