part of '../atoms.dart';

/// See [stateAtom].
class StateAtomBase<T> extends WritableAtom<T, T> {
  StateAtomBase(this.initialValue);

  /// The [T] that this atom contains when first read.
  final T initialValue;

  @override
  T $read(ctx) => initialValue;

  @override
  void $write(GetAtom get, SetAtom set, SetSelf<T> setSelf, T value) =>
      setSelf(value);
}

class StateAtom<T> extends StateAtomBase<T>
    with
        AtomConfigMixin<StateAtom<T>>,
        RefreshableAtomMixin<RefreshableStateAtom<T>> {
  StateAtom(super.initialValue);

  @override
  RefreshableStateAtom<T> refreshable() => RefreshableStateAtom(initialValue);
}

/// See [stateAtom].
class RefreshableStateAtom<T> = StateAtomBase<T>
    with AtomConfigMixin<RefreshableStateAtom<T>>, RefreshableAtom;

/// Create a simple atom with mutable state.
///
/// ```dart
/// final counter = stateAtom(0);
/// ```
///
/// If you want to ensure the state is not automatically disposed when not in
/// use, then call the [Atom.keepAlive] method.
///
/// ```dart
/// final counter = stateAtom(0).keepAlive();
/// ```
StateAtom<Value> stateAtom<Value>(Value initialValue) =>
    StateAtom(initialValue);
