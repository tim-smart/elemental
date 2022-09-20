part of 'internal.dart';

/// Represents a function that retrieves an [Atom]'s value.
typedef GetAtom = A Function<A>(Atom<A> atom);

/// Represents a function that sets a [WritableAtom]'s value.
typedef SetAtom = void Function<R, W>(WritableAtom<R, W> atom, W value);

/// Represents function that sets the current atom's value
typedef SetSelf<A> = void Function(A value);
