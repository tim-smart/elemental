import 'package:nucleus/nucleus.dart';

class Atom<Value> extends AtomBase<Value> {
  Atom(
    this.initialValue, {
    super.keepAlive,
  });

  final Value initialValue;

  @override
  Value read(AtomGetter getter) => getter(this);
}

// Function API

AtomBase<Value> atom<Value>(
  Value initialValue, {
  bool? keepAlive,
}) =>
    Atom(initialValue, keepAlive: keepAlive);
