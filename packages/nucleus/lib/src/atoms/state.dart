part of '../atoms.dart';

/// Represents an [Atom] that can be written to.
class StateAtom<R> extends WritableAtom<R, R> {
  StateAtom(this.initialValue);

  final R initialValue;

  @override
  R $read(AtomContext ctx) => initialValue;

  @override
  void $write(GetAtom get, SetAtom set, SetSelf<R> setSelf, R value) =>
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
WritableAtom<Value, Value> stateAtom<Value>(Value initialValue) =>
    StateAtom(initialValue);
