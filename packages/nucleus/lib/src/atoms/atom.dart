import 'package:nucleus/nucleus.dart';

abstract class Atom<R> {
  bool _touchedKeepAlive = false;
  bool _shouldKeepAlive = true;
  bool? get keepAliveOverride => _touchedKeepAlive ? _shouldKeepAlive : null;

  int? _hashCodeOverride;

  static A Function(Arg arg) family<A extends Atom, Arg>(
    A Function(Arg arg) create,
  ) {
    final familyHashCode = {}.hashCode;

    return (arg) {
      final atom = create(arg);
      atom._hashCodeOverride = familyHashCode ^ arg.hashCode;

      // Auto dispose by default
      if (!atom._touchedKeepAlive) {
        atom.autoDispose();
      }

      return atom;
    };
  }

  /// Used by the store
  R $read(AtomContext<dynamic> _) => read(AtomContextProxy(_));
  R read(AtomContext<R> _);

  Atom<B> select<B>(B Function(R a) f) =>
      ReadOnlyAtom((get) => f(get(this)))..autoDispose();

  void autoDispose() {
    _touchedKeepAlive = true;
    _shouldKeepAlive = false;
  }

  void keepAlive() {
    _touchedKeepAlive = true;
    _shouldKeepAlive = true;
  }

  AtomInitialValue withInitialValue(R value) => AtomInitialValue(this, value);

  @override
  operator ==(Object? other) => other.hashCode == hashCode;

  @override
  int get hashCode => _hashCodeOverride ?? super.hashCode;
}

typedef AtomGetter = R Function<R>(Atom<R> atom);
typedef AtomOnDispose = void Function(void Function());
typedef AtomSetter = void Function<W>(WritableAtom<dynamic, W> atom, W value);

typedef AtomReader<Value> = Value Function(AtomContext<Value> get);

class AtomInitialValue<A> {
  const AtomInitialValue(this.atom, this.value);
  final Atom<A> atom;
  final A value;
}

abstract class AtomContext<A> {
  Value call<Value>(Atom<Value> atom);
  void set<Value>(WritableAtom<dynamic, Value> atom, Value value);
  void setSelf(dynamic value);
  void onDispose(void Function() fn);
  Object? get previousValue;
}

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

abstract class WritableAtom<R, W> extends Atom<R> {
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
