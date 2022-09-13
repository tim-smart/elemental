import 'package:nucleus/nucleus.dart';

class PrimitiveAtom<Value> extends Atom<Value> {
  PrimitiveAtom(
    this.initialValue, {
    super.keepAlive,
  });

  final Value initialValue;

  @override
  Value read(AtomGetter getter) => getter(this);
}

// Function API

Atom<Value> atom<Value>(
  Value initialValue, {
  bool? keepAlive,
}) =>
    PrimitiveAtom(initialValue, keepAlive: keepAlive);
