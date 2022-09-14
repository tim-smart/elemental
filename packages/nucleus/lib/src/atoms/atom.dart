import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:nucleus/nucleus.dart';

typedef AtomGetter = R Function<R>(Atom<R, dynamic> atom);
typedef AtomReader<R> = R Function(AtomGetter get);
typedef AtomInitialValue = Tuple2<Atom, Object?>;

abstract class Atom<R, W> {
  bool _touchedKeepAlive = false;
  bool _shouldKeepAlive = true;
  bool get shouldKeepAlive => _shouldKeepAlive;

  int? _hashCodeOverride;

  static Atom<R, W> Function(Arg arg) family<R, W, Arg>(
    Atom<R, W> Function(Arg arg) create,
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

  R read(AtomGetter getter);

  Atom<B, void> select<B>(B Function(R a) f) =>
      ReadOnlyAtom((get) => f(get(this)));

  Atom<R, W> autoDispose() {
    _touchedKeepAlive = true;
    _shouldKeepAlive = false;
    return this;
  }

  Atom<R, W> keepAlive() {
    _touchedKeepAlive = true;
    _shouldKeepAlive = true;
    return this;
  }

  AtomInitialValue withInitialValue(R value) => Tuple2(this, value);

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
Atom<R, W> Function(Arg arg) atomFamily<R, W, Arg>(
  Atom<R, W> Function(Arg arg) create,
) =>
    Atom.family(create);
