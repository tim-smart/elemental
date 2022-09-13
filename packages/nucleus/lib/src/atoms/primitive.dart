import 'package:nucleus/nucleus.dart';

class PrimitiveAtom<Value> extends Atom<Value> {
  PrimitiveAtom(this.initialValue);

  final Value initialValue;

  @override
  Value read(AtomGetter getter) => getter(this);
}

// Function API

Atom<Value> atom<Value>(Value initialValue) => PrimitiveAtom(initialValue);
