part of '../atoms.dart';

/// See [stateAtom].
class StateAtom<Value> extends WritableAtom<Value, Value>
    with
        AtomConfigMixin<StateAtom<Value>>,
        RefreshableAtomMixin<RefreshableStateAtom<Value>> {
  StateAtom(this.initialValue);

  /// The [Value] that this atom contains when first read.
  final Value initialValue;

  @override
  Value $read(ctx) => initialValue;

  @override
  void $write(GetAtom get, SetAtom set, SetSelf<Value> setSelf, Value value) =>
      setSelf(value);

  @override
  RefreshableStateAtom<Value> refreshable() =>
      RefreshableStateAtom(initialValue);
}

/// See [stateAtom].
class RefreshableStateAtom<Value> extends WritableAtom<Value, Value>
    with AtomConfigMixin<RefreshableStateAtom<Value>>, RefreshableAtom {
  RefreshableStateAtom(this.initialValue);

  /// The [Value] that this atom contains when first read.
  final Value initialValue;

  @override
  Value $read(ctx) => initialValue;

  @override
  void $write(GetAtom get, SetAtom set, SetSelf<Value> setSelf, Value value) =>
      setSelf(value);
}

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
