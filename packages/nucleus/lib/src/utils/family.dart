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
