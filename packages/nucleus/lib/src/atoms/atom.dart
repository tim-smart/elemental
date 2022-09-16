import 'package:nucleus/nucleus.dart';

/// Base class for all atom's.
///
/// An atom is
abstract class Atom<R> {
  /// Create a family factory function, for indexing similar atoms with the
  /// [Arg] type.
  ///
  /// ```dart
  /// final userAtom = atomFamily((int id) => atom((get) => get(listOfUsers).getById(id)));
  ///
  /// // To get an atom that points to user with id 123
  /// final user123Atom = userAtom(123);
  /// ```
  static A Function(Arg arg) family<A extends Atom, Arg>(
    A Function(Arg arg) create,
  ) {
    final familyHashCode = {}.hashCode;

    return (arg) {
      final atom = create(arg);
      atom._hashCodeOverride = familyHashCode ^ arg.hashCode;
      return atom;
    };
  }

  /// Determines whether the state for this [Atom] is automatically disposed.
  ///
  /// If `true`, then the state will never be disposed. Defaults to `false`.
  bool get shouldKeepAlive => _shouldKeepAlive;
  bool _shouldKeepAlive = false;

  int? _hashCodeOverride;

  /// Used by the store
  R $read(AtomContext<dynamic> _) => read(AtomContextProxy(_));

  /// Used by the store
  R read(AtomContext<R> _);

  /// [select] part of the state of this atom, with the given function.
  Atom<B> select<B>(B Function(R a) f) => ReadOnlyAtom((get) => f(get(this)));

  /// Calling this on an atom will prevent its state from being automatically
  /// removed.
  void keepAlive() {
    _shouldKeepAlive = true;
  }

  /// Create an [AtomInitialValue] for this atom, for use with the
  /// `initialValues` parameter on a [Store] or [AtomScope] (from the
  /// flutter_nucleus package).
  AtomInitialValue withInitialValue(R value) => AtomInitialValue(this, value);

  @override
  operator ==(Object? other) => other.hashCode == hashCode;

  @override
  late final hashCode = _hashCodeOverride ?? super.hashCode;
}

/// Represents an atom value retrieval function
typedef AtomGetter = R Function<R>(Atom<R> atom);

/// Represents an atom value setter function
typedef AtomSetter = void Function<W>(WritableAtom<dynamic, W> atom, W value);

/// Represents an atom creation function
typedef AtomReader<Value> = Value Function(AtomContext<Value> get);

/// Returned from [Atom.withInitialValue] for passing to a [Store] or
/// [AtomScope].
class AtomInitialValue<A> {
  const AtomInitialValue(this.atom, this.value);
  final Atom<A> atom;
  final A value;
}

/// Passed to atom creation functions for managing state.
abstract class AtomContext<A> {
  /// An [AtomGetter] for retrieving an atom's value.
  Value call<Value>(Atom<Value> atom);

  /// An [AtomSetter] for setting an atom's value.
  void set<Value>(WritableAtom<dynamic, Value> atom, Value value);

  /// Set the state for the current atom
  void setSelf(A value);

  /// Register a callback for when this atom is disposed.
  void onDispose(void Function() fn);

  /// If an atom is recreated, then [previousValue] will contain the
  /// value from the previous state.
  A? get previousValue;
}

/// Used to proxy between a `dynamic` context to a strongly typed context.
class AtomContextProxy<A> extends AtomContext<A> {
  AtomContextProxy(this._base);

  final AtomContext<dynamic> _base;

  @override
  Value call<Value>(Atom<Value> atom) => _base.call(atom);

  @override
  void set<Value>(WritableAtom<dynamic, Value> atom, Value value) =>
      _base.set(atom, value);

  @override
  void setSelf(covariant A value) => _base.setSelf(value);

  @override
  late final A? previousValue = _base.previousValue as A?;

  @override
  void onDispose(void Function() fn) => _base.onDispose(fn);
}

/// A base class for all writable [Atom]'s.
abstract class WritableAtom<R, W> extends Atom<R> {
  /// Used by the [Store].
  void write(Store store, AtomSetter set, W value);
}

// Family creator

/// Create an atom factory indexed by the [Arg] type.
///
/// Automatically calls `.autoDipose()` on the child atoms, so to prevent state
/// from being removed, explicitly call `.keepAlive()` on the created atom.
A Function(Arg arg) atomFamily<A extends Atom, Arg>(
  A Function(Arg arg) create,
) =>
    Atom.family(create);
