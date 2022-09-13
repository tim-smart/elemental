import 'package:benchmark/benchmark.dart';
import 'package:nucleus/nucleus.dart';

final parent = atom(0);
final nucleus = atomFamily((int i) => readOnlyAtom((get) => get(parent) + i));

void main() {
  group('nucleus', () {
    benchmark('100k', () {
      final store = Store();
      for (var i = 0; i < 100000; i++) {
        final atom = nucleus(i);
        store.use(atom, () {
          final state = store.read(atom);
          store.put(atom, state + 1);
          final newState = store.read(atom);
        });
      }
    });
  });
}
