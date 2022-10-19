part of '../atoms.dart';

extension AtomExtension<A> on Atom<A> {
  /// Create a derived atom, that transforms an atoms value using the given
  /// function [f].
  ///
  /// Only rebuilds when the selected value changes.
  AtomWithParent<B, Atom<A>> select<B>(B Function(A value) f) =>
      AtomWithParent(this, (get, parent) => f(get(parent)));

  /// Create a derived atom, that filters the values using the given predicate.
  AtomWithParent<FutureValue<A>, Atom<A>> filter(
    bool Function(A value) predicate,
  ) =>
      AtomWithParent(this, (get, parent) {
        get.subscribe(parent, (A a) {
          if (predicate(a)) {
            get.setSelf(FutureValue.data(a));
          }
        }, fireImmediately: true);

        return get.self() ?? FutureValue.loading();
      });
}

extension FutureValueAtomExtension<A> on Atom<FutureValue<A>> {
  /// Create a derived atom, that transforms an atoms value using the given
  /// function [f].
  ///
  /// Only rebuilds when the selected value changes.
  AtomWithParent<B, Atom<FutureValue<A>>> rawSelect<B>(
    B Function(FutureValue<A> value) f,
  ) =>
      AtomWithParent(this, (get, parent) => f(get(parent)));

  /// Create a derived atom, that transforms an atoms value using the given
  /// function [f].
  ///
  /// Only rebuilds when the selected value changes.
  AtomWithParent<FutureValue<B>, Atom<FutureValue<A>>> select<B>(
    B Function(A value) f,
  ) =>
      AtomWithParent(this, (get, parent) {
        final value = get(parent).map(f);
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
  AtomWithParent<Future<B>, Atom<FutureValue<A>>> asyncSelect<B>(
    B Function(A value) f,
  ) =>
      select(f).rawSelect((a) => a.whenOrElse(
            data: Future.value,
            orElse: () => Future.any([]),
          ));
}

extension FutureValueAtomWithParentExtension<A, Parent extends Atom>
    on AtomWithParentBase<FutureValue<A>, Parent> {
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
