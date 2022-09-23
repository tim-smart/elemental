part of '../atoms.dart';

extension AtomExtension<A> on Atom<A> {
  /// Create a derived atom, that transforms an atoms value using the given
  /// function [f].
  Atom<B> select<B>(B Function(A value) f) =>
      ReadOnlyAtom((get) => f(get(this)));
}

extension FutureValueAtomExtension<A> on Atom<FutureValue<A>> {
  /// Create a derived atom, that transforms an atoms value using the given
  /// function [f].
  Atom<FutureValue<B>> select<B>(B Function(A value) f) => ReadOnlyAtom((get) {
        final value = get(this).map(f);
        if (value.dataOrNull != null) {
          // ignore: null_check_on_nullable_type_parameter
          return FutureValue.data(value.dataOrNull!);
        }

        if (get.previousValue is FutureData<B>) {
          return get.previousValue!;
        }

        return value;
      });

  /// Create a derived atom, that transforms an atoms value using the given
  /// function [f].
  Atom<Future<B>> asyncSelect<B>(B Function(A value) f) =>
      atomWithParent(ReadOnlyAtom<B?>((get) {
        final value = get(this).map(f);
        if (value.dataOrNull != null) {
          return value.dataOrNull;
        }

        if (get.previousValue != null) {
          return get.previousValue;
        }

        return null;
      }), (get, Atom<B?> parent) {
        final value = get(parent);
        return value == null ? Future.any([]) : Future.value(value);
      });
}
