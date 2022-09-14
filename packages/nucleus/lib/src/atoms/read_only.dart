import 'package:nucleus/nucleus.dart';

class ReadOnlyAtom<Value> extends Atom<Value, void> {
  ReadOnlyAtom(this._reader);

  final AtomReader<Value> _reader;

  @override
  Value read(AtomGetter getter) => _reader(getter);
}

// Function API

Atom<Value, void> readOnlyAtom<Value>(AtomReader<Value> create) =>
    ReadOnlyAtom(create);
