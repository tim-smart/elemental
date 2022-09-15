import 'package:nucleus/nucleus.dart';

typedef AtomGetter = R Function<R>(Atom<R> atom);
typedef AtomOnDispose = void Function(void Function());
typedef AtomSetter = void Function<W>(WritableAtom<dynamic, W> atom, W value);

typedef AtomReader<Value> = Value Function(
  AtomGetter get,
  void Function(void Function()) onDispose,
);

class AtomInitialValue<A> {
  const AtomInitialValue(this.atom, this.value);
  final Atom<A> atom;
  final A value;
}

abstract class Atom<R> {
  bool _touchedKeepAlive = false;
  bool _shouldKeepAlive = true;
  bool get shouldKeepAlive => _shouldKeepAlive;

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

  R read(AtomGetter getter, AtomOnDispose onDispose);

  Atom<B> select<B>(B Function(R a) f) =>
      ReadOnlyAtom((get, onDispose) => f(get(this)))..autoDispose();

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
