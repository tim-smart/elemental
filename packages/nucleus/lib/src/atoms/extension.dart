part of '../atoms.dart';

extension AtomExtension<A> on Atom<A> {
  /// Create a derived atom, that transforms an atoms value using the given
  /// function [f].
  ///
  /// Only rebuilds when the selected value changes.
  Atom<B> select<B>(B Function(A value) f) =>
      ReadOnlyAtom((get) => f(get(this)));
}

extension FutureValueAtomExtension<A> on Atom<FutureValue<A>> {
  /// Create a derived atom, that transforms an atoms value using the given
  /// function [f].
  ///
  /// Only rebuilds when the selected value changes.
  Atom<FutureValue<B>> select<B>(B Function(A value) f) => ReadOnlyAtom((get) {
        final value = get(this).map(f);
        if (value.dataOrNull != null) {
          // ignore: null_check_on_nullable_type_parameter
          return FutureValue.data(value.dataOrNull!);
        }

        final prev = get.self();
        if (prev is FutureData<B>) {
          return prev;
        }

        return value;
      });

  /// Create a derived atom, that transforms an atoms value using the given
  /// function [f].
  ///
  /// Only rebuilds when the selected value changes.
  Atom<Future<B>> asyncSelect<B>(B Function(A value) f) => atomWithParent(
        select(f),
        (get, Atom<FutureValue<B>> parent) => get(parent).whenOrElse(
          data: Future.value,
          orElse: () => Future.any([]),
        ),
      );
}
