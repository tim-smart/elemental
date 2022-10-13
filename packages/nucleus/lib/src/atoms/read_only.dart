part of '../atoms.dart';

/// See [atom].
abstract class ReadOnlyAtomBase<Value> extends Atom<Value> {
  ReadOnlyAtomBase(this.reader);

  final AtomReader<Value> reader;

  @override
  Value $read(ctx) => reader(ctx);
}

/// See [atom].
class ReadOnlyAtom<T> extends ReadOnlyAtomBase<T>
    with
        AtomConfigMixin<ReadOnlyAtom<T>>,
        RefreshableAtomMixin<RefreshableReadOnlyAtom<T>> {
  ReadOnlyAtom(super.reader);

  @override
  RefreshableReadOnlyAtom<T> refreshable() => RefreshableReadOnlyAtom(reader);
}

/// See [atom].
class RefreshableReadOnlyAtom<T> = ReadOnlyAtomBase<T>
    with AtomConfigMixin<RefreshableReadOnlyAtom<T>>, RefreshableAtom;

/// Create a read only atom that can interact with other atom's to create
/// derived state.
///
/// ```dart
/// final count = stateAtom(0);
/// final countTimesTwo = atom((get) => get(count) * 2);
/// ```
ReadOnlyAtom<Value> atom<Value>(AtomReader<Value> create) =>
    ReadOnlyAtom(create);
