import 'package:nucleus/nucleus.dart';

typedef ProxyAtomWriter<W> = void Function(
  AtomGetter get,
  AtomSetter set,
  W value,
);

class ProxyAtom<R, W> extends WritableAtom<R, W> {
  ProxyAtom(this._reader, this._writer);

  final AtomReader<R> _reader;
  final ProxyAtomWriter<W> _writer;

  @override
  R read(AtomGetter getter, AtomOnDispose onDispose) =>
      _reader(getter, onDispose);

  @override
  void write(Store store, AtomSetter set, W value) {
    _writer(store.read, store.put, value);
  }
}

WritableAtom<R, W> proxyAtom<R, W>(
  AtomReader<R> create,
  ProxyAtomWriter<W> writer,
) =>
    ProxyAtom(create, writer);
