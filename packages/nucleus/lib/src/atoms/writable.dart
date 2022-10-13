part of '../atoms.dart';

/// Represents an [Atom] that can be written to.
abstract class WritableAtomBase<R, W> extends Atom<R> {
  /// When the atom recieves a write with the given [value], this method
  /// determines the outcome.
  void $write(GetAtom get, SetAtom set, SetSelf<R> setSelf, W value);
}

/// Represents an [Atom] that can be written to.
abstract class WritableAtom<R, W> extends WritableAtomBase<R, W>
    with
        AtomConfigMixin<WritableAtom<R, W>>,
        RefreshableAtomMixin<RefreshableWritableAtom<R, W>> {
  @override
  RefreshableWritableAtom<R, W> refreshable() => RefreshableWritableAtom(this);
}

/// Represents an [Atom] that can be written to.
class RefreshableWritableAtom<R, W> extends WritableAtomBase<R, W>
    with AtomConfigMixin<RefreshableWritableAtom<R, W>>, RefreshableAtom {
  RefreshableWritableAtom(this._parent);

  final WritableAtom<R, W> _parent;

  @override
  R $read(AtomContext<R> ctx) => _parent.$read(ctx);

  @override
  void $write(GetAtom get, SetAtom set, SetSelf<R> setSelf, W value) =>
      _parent.$write(get, set, setSelf, value);
}

class _WritableAtomImpl<R, W> extends WritableAtom<R, W> {
  _WritableAtomImpl(this.reader, this.writer);

  final AtomReader<R> reader;
  final AtomWriter<R, W> writer;

  @override
  R $read(AtomContext<R> ctx) => reader(ctx);

  @override
  void $write(GetAtom get, SetAtom set, SetSelf<R> setSelf, W value) =>
      writer(get, set, setSelf, value);
}

/// Creates an [WritableAtom] that can be used to implement custom write logic.
///
/// See [stateAtomWithStorage] for an example, where writes are intercepted and
/// sent to a [NucleusStorage] instance.
WritableAtom<R, W> writableAtom<R, W>(
  AtomReader<R> reader,
  AtomWriter<R, W> writer,
) =>
    _WritableAtomImpl(reader, writer);
