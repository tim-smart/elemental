import 'package:fast_immutable_collections/fast_immutable_collections.dart';

typedef AtomGetter = A Function<A>(Atom<A> atom);
typedef AtomReader<Value> = Value Function(AtomGetter get);
typedef AtomInitialValue = Tuple2<Atom, Object?>;

abstract class Atom<Value> {
  bool _calledKeepAlive = false;
  bool _shouldKeepAlive = true;
  bool get shouldKeepAlive => _shouldKeepAlive;

  int? _hashCodeOverride;

  static Atom<Value> Function(Arg arg) family<Value, Arg>(
    Atom<Value> Function(Arg arg) create,
  ) {
    final familyAtom = {};
    final familyHashCode = familyAtom.hashCode;

    return (arg) {
      final atom = create(arg);
      atom._hashCodeOverride = familyHashCode ^ arg.hashCode;

      // Auto dispose by default
      if (atom.shouldKeepAlive && !atom._calledKeepAlive) {
        atom.autoDispose();
      }

      return atom;
    };
  }

  Value read(AtomGetter getter);

  Atom<Value> autoDispose() {
    _shouldKeepAlive = false;
    return this;
  }

  Atom<Value> keepAlive() {
    _shouldKeepAlive = true;
    _calledKeepAlive = true;
    return this;
  }

  AtomInitialValue withInitialValue(Value value) => Tuple2(this, value);

  @override
  operator ==(Object? other) => other.hashCode == hashCode;

  @override
  int get hashCode => _hashCodeOverride ?? super.hashCode;
}

// Family creator

Atom<Value> Function(Arg arg) atomFamily<Value, Arg>(
  Atom<Value> Function(Arg arg) create,
) =>
    Atom.family(create);
