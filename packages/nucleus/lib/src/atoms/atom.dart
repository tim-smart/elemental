import 'package:nucleus/nucleus.dart';

import '../internal/internal.dart';

/// The base class for all atoms.
///
/// An atom is a special identifiet, that points to some state in an [AtomRegistry].
///
/// It also contains configuration that determines how its state is read, or
/// written (see [WritableAtom]).
abstract class Atom<T> {
  /// Used by the registry to read the atoms value.
  T read(AtomContext<T> ctx);

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

  /// Create a derived atom, that ransforms an atoms value using the given
  /// function [f].
  Atom<A> select<A>(A Function(T value) f) =>
      ReadOnlyAtom((get) => f(get(this)));

  /// Should this atoms state be kept, even if it isnt being used?
  ///
  /// Defaults to `false`.
  bool get shouldKeepAlive => _keepAlive;
  bool _keepAlive = false;

  /// Prevent the state of this atom from being automatically disposed.
  void keepAlive() {
    _keepAlive = true;
  }

  /// Create an initial value override, which can be given to an [AtomScope] or
  /// [AtomRegistry].
  AtomInitialValue withInitialValue(T value) => AtomInitialValue(this, value);

  /// Used by the registry.
  T $read({
    required GetAtom get,
    required SetAtom set,
    required OnDispose onDispose,
    required SetSelf<T> setSelf,
    required SubscribeToAtom subscribe,
    required T? previousValue,
    required AssertNotDisposed assertNotDisposed,
  }) =>
      read(_AtomContextProxy._(
        get,
        set,
        onDispose,
        setSelf,
        subscribe,
        previousValue,
        assertNotDisposed,
      ));

  int? _hashCodeOverride;

  @override
  late final hashCode = _hashCodeOverride ?? super.hashCode;

  @override
  operator ==(Object? other) => other.hashCode == hashCode;
}

/// Represents an [Atom] that can be written to.
abstract class WritableAtom<R, W> extends Atom<R> {
  /// When the atom recieves a write with the given [value], this method
  /// determines the outcome.
  void write(GetAtom get, SetAtom set, SetSelf<R> setSelf, W value);
}

/// Passed to the [Atom.read] methof, allowing you to interact with other atoms
/// and manage the lifecycle of your state.
abstract class AtomContext<T> {
  /// Get the value for the given [atom].
  R call<R>(Atom<R> atom);

  /// Get the value for the given [atom].
  R get<R>(Atom<R> atom);

  /// Set the value for the given [atom].
  void set<R, W>(WritableAtom<R, W> atom, W value);

  /// Set the value for the current atom.
  void setSelf(T value);

  /// Subscribe to the given [atom].
  void Function() subscribe(Atom atom, void Function() handler);

  /// Register an [cb] function, that is called when the atom is invalidated or
  /// disposed.
  ///
  /// Can be called multiple times.
  void onDispose(void Function() cb);

  /// The previous value of this atom.
  T? get previousValue;
}

class _AtomContextProxy<T> implements AtomContext<T> {
  _AtomContextProxy._(
    this._get,
    this._set,
    this._onDispose,
    this._setSelf,
    this._subscribe,
    this.previousValue,
    this._assert,
  );

  final GetAtom _get;
  final SetAtom _set;
  final OnDispose _onDispose;
  final SetSelf<T> _setSelf;
  final SubscribeToAtom _subscribe;
  final AssertNotDisposed _assert;

  @override
  final T? previousValue;

  @override
  A call<A>(Atom<A> atom) {
    return _get(atom);
  }

  @override
  A get<A>(Atom<A> atom) {
    return _get(atom);
  }

  @override
  void set<R, W>(WritableAtom<R, W> atom, W value) {
    _assert("set");
    _set(atom, value);
  }

  @override
  void setSelf(T value) {
    _assert("setSelf");
    _setSelf(value);
  }

  @override
  void Function() subscribe(Atom atom, void Function() handler) =>
      _subscribe(atom, handler);

  @override
  void onDispose(void Function() cb) => _onDispose(cb);
}

typedef AtomReader<R> = R Function(AtomContext<R> get);

/// Returned from [Atom.withInitialValue] for passing to a [AtomRegistry] or
/// [AtomScope].
class AtomInitialValue<A> {
  const AtomInitialValue(this.atom, this.value);
  final Atom<A> atom;
  final A value;
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
