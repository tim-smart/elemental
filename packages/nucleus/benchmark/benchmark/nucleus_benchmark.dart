import 'package:benchmark/benchmark.dart';
import 'package:nucleus/nucleus.dart';

final value = stateAtom(0)..keepAlive();
final nucleus = atomFamily((int i) => stateAtom(i));
final nested = atom((get) => List.generate(
      1000000,
      (i) => stateAtom(i),
    ));

final depOne = atom((get) => get(value) * 10);
final depTwo = atom((get) => get(depOne) * 10);
final depThree = atom((get) => get(depTwo) * 10);

void main() {
  group('nucleus', () {
    benchmark('read 1000k', () {
      final store = AtomRegistry();
      for (var i = 0; i < 1000000; i++) {
        store.get(value);
      }
    }, iterations: 1);

    benchmark('state 100k', () {
      final store = AtomRegistry();
      for (var i = 0; i < 100000; i++) {
        final atom = nucleus(i);
        final state = store.get(atom);
        store.set(atom, state + 1);
        store.get(atom);
      }
    }, iterations: 1);

    benchmark('state 10k', () {
      final store = AtomRegistry();
      for (var i = 0; i < 10000; i++) {
        final atom = nucleus(i);
        final state = store.get(atom);
        store.set(atom, state + 1);
        store.get(atom);
      }
    }, iterations: 1);

    benchmark('deps state 10k', () {
      final store = AtomRegistry();
      for (var i = 0; i < 10000; i++) {
        final state = store.get(value);
        store.set(value, state + 1);
        store.get(depThree);
      }
    }, iterations: 1);

    benchmark('nesting', () {
      final store = AtomRegistry();
      store.get(nested).map(store.get);
    }, iterations: 1);
  });
}
