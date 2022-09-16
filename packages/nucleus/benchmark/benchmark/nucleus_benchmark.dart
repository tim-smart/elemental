import 'package:benchmark/benchmark.dart';
import 'package:nucleus/nucleus.dart';

final value = stateAtom(0)..keepAlive();
final nucleus = atomFamily((int i) => stateAtom(i));
final nested = atom((get) => List.generate(
      100000,
      (i) => stateAtom(i),
    ));

final depOne = atom((get) => get(value) * 10);
final depTwo = atom((get) => get(depOne) * 10);
final depThree = atom((get) => get(depTwo) * 10);

void main() {
  group('nucleus', () {
    benchmark('read 1000k', () {
      final store = Store();
      for (var i = 0; i < 1000000; i++) {
        store.read(value);
      }
    }, iterations: 1);

    benchmark('state 100k', () {
      final store = Store();
      for (var i = 0; i < 100000; i++) {
        final atom = nucleus(i);
        final state = store.read(atom);
        store.put(atom, state + 1);
        store.read(atom);
      }
    }, iterations: 1);

    benchmark('state 10k', () {
      final store = Store();
      for (var i = 0; i < 10000; i++) {
        final atom = nucleus(i);
        final state = store.read(atom);
        store.put(atom, state + 1);
        store.read(atom);
      }
    }, iterations: 1);

    benchmark('deps state 10k', () {
      final store = Store();
      for (var i = 0; i < 10000; i++) {
        final state = store.read(value);
        store.put(value, state + 1);
        store.read(depThree);
      }
    }, iterations: 1);

    benchmark('nesting', () {
      final store = Store();
      store.read(nested).map(store.read);
    });
  });
}
