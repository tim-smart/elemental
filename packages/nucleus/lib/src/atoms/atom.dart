import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:nucleus/nucleus.dart';

typedef AtomGetter = A Function<A>(Atom<A> atom);
typedef AtomReader<Value> = Value Function(AtomGetter get);
typedef AtomInitialValue = Tuple2<Atom, Object?>;

abstract class Atom<Value> {
  bool _touchedKeepAlive = false;
  bool _shouldKeepAlive = true;
  bool get shouldKeepAlive => _shouldKeepAlive;

  int? _hashCodeOverride;

  static Atom<Value> Function(Arg arg) family<Value, Arg>(
    Atom<Value> Function(Arg arg) create,
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

  Value read(AtomGetter getter);

  Atom<B> select<B>(B Function(Value a) f) =>
      ReadOnlyAtom((get) => f(get(this)));

  Atom<Value> autoDispose() {
    _touchedKeepAlive = true;
    _shouldKeepAlive = false;
    return this;
  }

  Atom<Value> keepAlive() {
    _touchedKeepAlive = true;
    _shouldKeepAlive = true;
    return this;
  }

  AtomInitialValue withInitialValue(Value value) => Tuple2(this, value);

  @override
  operator ==(Object? other) => other.hashCode == hashCode;

  @override
  int get hashCode => _hashCodeOverride ?? super.hashCode;
}

// Family creator

/// Create an atom factory indexed by the [Arg] type.
///
/// Automatically calls `.autoDipose()` on the child atoms, so to prevent state
/// from being removed, explicitly call `.keepAlive()` on the created atom.
Atom<Value> Function(Arg arg) atomFamily<Value, Arg>(
  Atom<Value> Function(Arg arg) create,
) =>
    Atom.family(create);
