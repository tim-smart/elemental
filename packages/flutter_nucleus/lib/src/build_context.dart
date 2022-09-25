import 'package:flutter/material.dart';
import 'package:flutter_nucleus/flutter_nucleus.dart';

extension NucleusBuildContextExt on BuildContext {
  /// Read an atom once
  A getAtom<A>(Atom<A> atom) =>
      AtomScope.registryOf(this, listen: false).get(atom);

  /// Create a setter function for an atom.
  void Function(A value) setAtom<A>(WritableAtom<dynamic, A> atom) {
    final registry = AtomScope.registryOf(this);
    return (value) => registry.set(atom, value);
  }

  /// Create an updater function for an atom.
  void Function(W Function(R value)) updateAtom<R, W>(WritableAtom<R, W> atom) {
    final registry = AtomScope.registryOf(this);
    return (f) => registry.set(atom, f(registry.get(atom)));
  }

  AtomRegistry registry({listen = true}) =>
      AtomScope.registryOf(this, listen: listen);
}
