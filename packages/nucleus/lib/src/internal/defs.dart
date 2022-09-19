part of 'internal.dart';

typedef OnSetSelf = void Function();
typedef OnDispose = void Function(void Function());
typedef AssertNotDisposed = void Function(String method);
typedef AddParent = void Function(Node node);
typedef GetPreviousValue<A> = A? Function();

/// Represents a function that retrieves an [Atom]'s value.
typedef GetAtom = A Function<A>(Atom<A> atom);

/// Represents a function that sets a [WritableAtom]'s value.
typedef SetAtom = void Function<R, W>(WritableAtom<R, W> atom, W value);

typedef SetSelf<A> = void Function(A value);

typedef SubscribeToAtom = void Function() Function(
  Atom atom,
  void Function() handler,
);
