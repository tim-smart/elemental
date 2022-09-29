part of '../atoms.dart';

/// Represents the `writer` argument to [proxyAtom]
typedef ProxyAtomWriter<R, W> = void Function(
  GetAtom get,
  SetAtom set,
  SetSelf<R> setSelf,
  W value,
);

/// See [proxyAtom].
class ProxyAtom<R, W> extends WritableAtom<R, W> {
  ProxyAtom(this._reader, this._writer);

  final AtomReader<R> _reader;
  final ProxyAtomWriter<R, W> _writer;

  @override
  R $read(ctx) => _reader(ctx);

  @override
  void $write(GetAtom get, SetAtom set, SetSelf<R> setSelf, W value) {
    _writer(get, set, setSelf, value);
  }
}

/// Creates an [WritableAtom] that can be used to implement custom write logic.
///
/// See [stateAtomWithStorage] for an example, where writes are intercepted and
/// sent to a [NucleusStorage] instance.
WritableAtom<R, W> proxyAtom<R, W>(
  AtomReader<R> create,
  ProxyAtomWriter<R, W> writer,
) =>
    ProxyAtom(create, writer);
