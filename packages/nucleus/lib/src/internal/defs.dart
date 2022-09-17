import 'package:nucleus/nucleus.dart';

import 'internal.dart';

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

typedef LifetimeDepsFn<A> = A Function(
  OnDispose onDispose,
  AssertNotDisposed assertNotDisposed,
);
typedef NodeDepsFn<A> = LifetimeDepsFn<A> Function(
  AddParent addParent,
  SetSelf<A> setSelf,
  GetPreviousValue<A> getPreviousValue,
);
typedef RegistryDepsFn<A> = NodeDepsFn<A> Function(
  GetAtom get,
  SetAtom set,
);
