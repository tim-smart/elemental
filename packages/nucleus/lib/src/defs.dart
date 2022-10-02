import 'package:nucleus/nucleus.dart';

/// Represents a function that retrieves an [Atom]'s value.
typedef GetAtom = A Function<A>(Atom<A> atom);

/// Represents a function that sets a [WritableAtom]'s value.
typedef SetAtom = void Function<R, W>(WritableAtom<R, W> atom, W value);

/// Represents function that sets the current atom's value
typedef SetSelf<A> = void Function(A value);

/// A function that creates a value from an [AtomContext]
typedef AtomReader<R> = R Function(AtomContext<R> get);

/// Represents the `writer` argument to [writableAtom]
typedef AtomWriter<R, W> = void Function(
  GetAtom get,
  SetAtom set,
  SetSelf<R> setSelf,
  W value,
);

/// Returned from [Atom.withInitialValue] for passing to a [AtomRegistry] or
/// [AtomScope].
class AtomInitialValue<A> {
  const AtomInitialValue(this.atom, this.value);
  final Atom<A> atom;
  final A value;
}
