part of '../atoms.dart';

/// See [atom].
class ReadOnlyAtom<Value> extends Atom<Value>
    with
        AtomConfigMixin<ReadOnlyAtom<Value>>,
        RefreshableAtomMixin<RefreshableReadOnlyAtom<Value>> {
  ReadOnlyAtom(this._reader);

  final AtomReader<Value> _reader;

  @override
  Value $read(ctx) => _reader(ctx);

  @override
  RefreshableReadOnlyAtom<Value> refreshable() =>
      RefreshableReadOnlyAtom(_reader);
}

/// See [atom].
class RefreshableReadOnlyAtom<Value> extends Atom<Value>
    with AtomConfigMixin<RefreshableReadOnlyAtom<Value>>, RefreshableAtom {
  RefreshableReadOnlyAtom(this._reader);

  final AtomReader<Value> _reader;

  @override
  Value $read(ctx) => _reader(ctx);
}

/// Create a read only atom that can interact with other atom's to create
/// derived state.
///
/// ```dart
/// final count = stateAtom(0);
/// final countTimesTwo = atom((get) => get(count) * 2);
/// ```
ReadOnlyAtom<Value> atom<Value>(AtomReader<Value> create) =>
    ReadOnlyAtom(create);
