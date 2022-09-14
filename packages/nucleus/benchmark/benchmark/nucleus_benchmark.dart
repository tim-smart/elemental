import 'package:benchmark/benchmark.dart';
import 'package:nucleus/nucleus.dart';

final nucleus = atomFamily((int i) => stateAtom(i));
final nested = atom((_) => List.generate(
      100000,
      (i) => stateAtom(i),
    ));

void main() {
  group('nucleus', () {
    benchmark('100k', () {
      final store = Store();
      for (var i = 0; i < 100000; i++) {
        final atom = nucleus(i);
        final state = store.read(atom);
        store.put(atom, state + 1);
        store.read(atom);
      }
    }, iterations: 1);

    benchmark('10k', () {
      final store = Store();
      for (var i = 0; i < 10000; i++) {
        final atom = nucleus(i);
        final state = store.read(atom);
        store.put(atom, state + 1);
        store.read(atom);
      }
    }, iterations: 1);

    benchmark('nesting', () {
      final store = Store();
      store.read(nested).map(store.read);
    });
  });
}
