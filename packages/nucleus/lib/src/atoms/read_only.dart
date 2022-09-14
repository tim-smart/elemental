import 'package:nucleus/nucleus.dart';

class ReadOnlyAtom<Value> extends Atom<Value> {
  ReadOnlyAtom(this._reader);

  final AtomReader<Value> _reader;

  @override
  Value read(AtomGetter getter) => _reader(getter);
}

// Function API

Atom<Value> atom<Value>(AtomReader<Value> create) => ReadOnlyAtom(create);
