import 'package:nucleus/nucleus.dart';

class StateAtom<Value> extends WritableAtom<Value, Value> {
  StateAtom(this.initialValue);

  final Value initialValue;

  @override
  Value read(AtomGetter getter, AtomOnDispose onDispose) => getter(this);

  @override
  void write(Store store, AtomSetter set, Value value) {
    set(this, value);
  }
}

// Function API

WritableAtom<Value, Value> stateAtom<Value>(Value initialValue) =>
    StateAtom(initialValue);
