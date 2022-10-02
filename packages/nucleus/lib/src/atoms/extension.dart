part of '../atoms.dart';

extension AtomExtension<A> on Atom<A> {
  /// Create a derived atom, that transforms an atoms value using the given
  /// function [f].
  ///
  /// Only rebuilds when the selected value changes.
  AtomWithParent<B, Atom<A>> select<B>(B Function(A value) f) =>
      AtomWithParent(this, (get, parent) => f(get(parent)));
}

extension FutureValueAtomExtension<A, Parent extends Atom>
    on AtomWithParent<FutureValue<A>, Parent> {
  /// Create a derived atom, that transforms an atoms value using the given
  /// function [f].
  ///
  /// Only rebuilds when the selected value changes.
  AtomWithParent<B, Parent> rawSelect<B>(
    B Function(FutureValue<A> value) f,
  ) =>
      AtomWithParent(parent, (get, parent) => f(get(this)));

  /// Create a derived atom, that transforms an atoms value using the given
  /// function [f].
  ///
  /// Only rebuilds when the selected value changes.
  AtomWithParent<FutureValue<B>, Parent> select<B>(
    B Function(A value) f,
  ) =>
      AtomWithParent(parent, (get, parent) {
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
  AtomWithParent<Future<B>, Parent> asyncSelect<B>(
    B Function(A value) f,
  ) =>
      select(f).rawSelect((a) => a.whenOrElse(
            data: Future.value,
            orElse: () => Future.any([]),
          ));
}
