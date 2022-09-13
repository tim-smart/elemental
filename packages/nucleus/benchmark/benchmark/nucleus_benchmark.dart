import 'package:benchmark/benchmark.dart';
import 'package:nucleus/nucleus.dart';

final nucleus = atomFamily((int i) => atom(i));
final nested = readOnlyAtom((_) => List.generate(
      100000,
      (i) => atom(i),
    ));

void main() {
  group('nucleus', () {
    benchmark('1000k', () {
      final store = Store();
      for (var i = 0; i < 1000000; i++) {
        final atom = nucleus(i);
        final state = store.read(atom);
        store.put(atom, state + 1);
        store.read(atom);
      }
    }, iterations: 3);

    benchmark('nesting', () {
      final store = Store();
      store.read(nested).map(store.read);
    });
  });
}
