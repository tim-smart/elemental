import 'dart:developer';

import 'package:nucleus/nucleus.dart';

final value = stateAtom(0)..keepAlive();
final depOne = atom((get) => get(value) * 10);
final depTwo = atom((get) => get(depOne) * 10);
final depThree = atom((get) => get(depTwo) * 10);

void main() {
  final store = AtomRegistry();
  for (var i = 0; i < 1000000; i++) {
    final state = store.get(value);
    store.set(value, state + 1);
    store.get(depThree);
  }
  debugger();
}
