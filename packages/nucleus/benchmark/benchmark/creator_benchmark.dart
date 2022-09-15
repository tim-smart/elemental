import 'package:benchmark/benchmark.dart';
import 'package:creator_core/creator_core.dart';

final value = Creator.value(0);
final family = Creator.arg1((ref, int i) => i);
final nested = Creator((ref) => List.generate(100000, (i) => Creator.value(i)));

void main() {
  group('creator', () {
    benchmark('read 1000k', () {
      final ref = Ref();
      for (var i = 0; i < 1000000; i++) {
        ref.read(value);
      }
    }, iterations: 1);

    benchmark('state 100k', () {
      final ref = Ref();
      for (var i = 0; i < 100000; i++) {
        final c = family(i);
        final state = ref.read(c);
        ref.set(c, state + 1);
        ref.read(c);
      }
    }, iterations: 1);

    benchmark('state 10k', () {
      final ref = Ref();
      for (var i = 0; i < 10000; i++) {
        final c = family(i);
        final state = ref.read(c);
        ref.set(c, state + 1);
        ref.read(c);
      }
    }, iterations: 1);

    benchmark('nesting', () {
      final store = Ref();
      store.read(nested).map(store.read);
    });
  });
}
