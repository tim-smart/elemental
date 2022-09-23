part of '../atoms.dart';

extension AtomExtension<A> on Atom<A> {
  /// Create a derived atom, that transforms an atoms value using the given
  /// function [f].
  Atom<B> select<B>(B Function(A value) f) =>
      ReadOnlyAtom((get) => f(get(this)));

  /// Create a derived atom, using an asynchronous function.
  FutureAtom<B> asyncSelect<B>(Future<B> Function(A value) f) =>
      futureAtom((get) => f(get(this)));
}

extension FutureAtomExtension<A> on FutureAtom<A> {
  /// Create a derived atom, that transforms an atoms value using the given
  /// function [f].
  FutureAtom<B> select<B>(B Function(A value) f) =>
      futureAtom((get) => get(parent).then(f));

  /// Create a derived atom, using an asynchronous function.
  FutureAtom<B> asyncSelect<B>(Future<B> Function(A value) f) =>
      futureAtom((get) => get(parent).then(f));
}

extension StreamAtomExtension<A> on StreamAtom<A> {
  /// Create a derived atom, that transforms an atoms value using the given
  /// function [f].
  StreamAtom<B> select<B>(B Function(A value) f) =>
      streamAtom((get) => get(parent).map(f));

  /// Create a derived atom, using an asynchronous function.
  StreamAtom<B> asyncSelect<B>(Future<B> Function(A value) f) =>
      streamAtom((get) => get(parent).asyncMap(f));
}
