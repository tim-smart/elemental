part of '../atoms.dart';

/// The base class for all atoms.
///
/// An atom is a special identifiet, that points to some state in an [AtomRegistry].
///
/// It also contains configuration that determines how its state is read, or
/// written (see [WritableAtom]).
abstract class Atom<T> {
  /// Used by the registry to read the atoms value.
  T $read(AtomContext<T> ctx);

  /// Used by the registry to create a read lifetime. Bit hacky, but allows us
  /// to go from dynamic to T.
  ReadLifetime<T> $lifetime(Node node) => ReadLifetime(node);

  /// Should this atoms state be kept, even if it isnt being used?
  ///
  /// Defaults to `false`.
  bool get shouldKeepAlive => _keepAlive;
  bool _keepAlive = false;

  /// Debug name for this atom
  String? get name => _name;
  String? _name;

  /// Create an initial value override, which can be given to an [AtomScope] or
  /// [AtomRegistry].
  ///
  /// By default it calls [Atom.keepAlive], to ensure the initial value is not
  /// disposed.
  AtomInitialValue withInitialValue(
    T value, {
    bool keepAlive = true,
  }) {
    if (keepAlive) {
      _keepAlive = true;
    }
    return AtomInitialValue(this, value);
  }

  @override
  String toString() => "$runtimeType(name: $_name)";
}

class AtomConfigMixin<A extends Atom> {
  /// Prevent the state of this atom from being automatically disposed.
  A keepAlive() {
    (this as A)._keepAlive = true;
    return this as A;
  }

  /// Set a name for debugging
  A setName(String name) {
    (this as A)._name = name;
    return this as A;
  }
}

mixin RefreshableAtomMixin<A extends RefreshableAtom> {
  /// Create a refreshable version of this atom, which can be used with
  /// [AtomRegistry.refresh] or [AtomContext.refresh].
  A refreshable();
}

mixin RefreshableAtom {
  /// Determines refresh behaviour.
  void $refresh(void Function(Atom atom) refresh) => refresh(this as Atom);
}
