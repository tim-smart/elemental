import 'package:nucleus/nucleus.dart';

typedef ProxyAtomWriter<W, PW> = PW Function(W nextValue, AtomGetter get);

class ProxyAtom<R, W, PW> extends Atom<R, W> {
  ProxyAtom(this.parent, this._reader, [this.writer]);

  final Atom<dynamic, PW> parent;
  final AtomReader<R> _reader;
  final ProxyAtomWriter<W, PW>? writer;

  @override
  R read(AtomGetter getter) => _reader(getter);

  void write(Store store, W value) {
    if (writer != null) {
      final parentValue = writer!(value, store.read);
      return store.put(parent, parentValue);
    }

    store.put(parent, value);
  }
}

Atom<R, W> proxyAtom<R, W>(
  Atom<dynamic, W> atom,
  AtomReader<R> create,
) =>
    ProxyAtom(atom, create);

Atom<R, W> proxyAtomWithWriter<R, W, PW>(
  Atom<dynamic, PW> atom,
  AtomReader<R> create,
  ProxyAtomWriter<W, PW> writer,
) =>
    ProxyAtom(atom, create, writer);
