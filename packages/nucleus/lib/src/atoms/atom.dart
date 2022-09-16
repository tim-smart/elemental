import '../internal/internal.dart';

abstract class Atom<T> {
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

  T $read({
    required GetAtom get,
    required SetAtom set,
    required OnDispose onDispose,
    required SetSelf<T> setSelf,
    required T? previousValue,
    required AssertNotDisposed assertNotDisposed,
  }) =>
      read(AtomContextProxy._(
        get,
        set,
        onDispose,
        setSelf,
        previousValue,
        assertNotDisposed,
      ));

  bool _keepAlive = false;
  bool get shouldKeepAlive => _keepAlive;

  void keepAlive() {
    _keepAlive = true;
  }

  int? _hashCodeOverride;

  @override
  late final hashCode = _hashCodeOverride ?? super.hashCode;

  @override
  operator ==(Object? other) => other.hashCode == hashCode;
}

abstract class WritableAtom<R, W> extends Atom<R> {
  void write(GetAtom get, SetAtom set, SetSelf<R> setSelf, W value);
}

abstract class AtomContext<T> {
  R call<R>(Atom<R> atom);
  R get<R>(Atom<R> atom);
  void set<R, W>(WritableAtom<R, W> atom, W value);
  void setSelf(T value);
  void onDispose(void Function() cb);
  T? get previousValue;
}

class AtomContextProxy<T> implements AtomContext<T> {
  AtomContextProxy._(
    this._get,
    this._set,
    this._onDispose,
    this._setSelf,
    this.previousValue,
    this._assert,
  );

  final GetAtom _get;
  final SetAtom _set;
  final OnDispose _onDispose;
  final SetSelf<T> _setSelf;
  final AssertNotDisposed _assert;

  @override
  final T? previousValue;

  @override
  A call<A>(Atom<A> atom) {
    _assert("get");
    return _get(atom);
  }

  @override
  A get<A>(Atom<A> atom) {
    _assert("get");
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
