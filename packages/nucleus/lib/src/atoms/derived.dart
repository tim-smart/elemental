import 'package:nucleus/nucleus.dart';

class DerivedAtom<Value> extends AtomBase<Value> {
  DerivedAtom(
    this._reader, {
    super.keepAlive,
  });

  final AtomReader<Value> _reader;

  @override
  Value read(AtomGetter getter) => _reader(getter);
}

// Function API

AtomBase<Value> derivedAtom<Value>(
  AtomReader<Value> create, {
  bool? keepAlive,
}) =>
    DerivedAtom(
      create,
      keepAlive: keepAlive,
    );
