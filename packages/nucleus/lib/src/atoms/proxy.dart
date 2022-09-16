import 'package:nucleus/nucleus.dart';

/// Represents the `writer` argument to [proxyAtom]
typedef ProxyAtomWriter<W> = void Function(
  AtomGetter get,
  AtomSetter set,
  W value,
);

/// See [proxyAtom].
class ProxyAtom<R, W> extends WritableAtom<R, W> {
  ProxyAtom(this._reader, this._writer);

  final AtomReader<R> _reader;
  final ProxyAtomWriter<W> _writer;

  @override
  R read(_) => _reader(_);

  @override
  void write(Store store, AtomSetter set, W value) =>
      _writer(store.read, store.put, value);
}

/// Creates an [WritableAtom] that can be used to implement custom write logic.
///
/// See [stateAtomWithStorage] for an example, where writes are intercepted and
/// sent to a [NucleusStorage] instance.
WritableAtom<R, W> proxyAtom<R, W>(
  AtomReader<R> create,
  ProxyAtomWriter<W> writer,
) =>
    ProxyAtom(create, writer);
