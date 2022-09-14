import 'package:benchmark/benchmark.dart';
import 'package:riverpod/riverpod.dart';

final value = Provider((ref) => 0);
final riverpod = StateProvider.family((ref, int i) => i);
final nested = Provider((ref) => List.generate(
      100000,
      (i) => StateProvider.autoDispose((_) => i),
    ));

void main() {
  group('riverpod', () {
    benchmark('read 1000k', () {
      final container = ProviderContainer();
      for (var i = 0; i < 1000000; i++) {
        container.read(value);
      }
    }, iterations: 1);

    benchmark('state 100k', () {
      final container = ProviderContainer();
      for (var i = 0; i < 100000; i++) {
        final state = container.read(riverpod(i));
        container.read(riverpod(i).notifier).state = state + 1;
        container.read(riverpod(i));
      }
    }, iterations: 1);

    benchmark('state 10k', () {
      final container = ProviderContainer();
      for (var i = 0; i < 10000; i++) {
        final state = container.read(riverpod(i));
        container.read(riverpod(i).notifier).state = state + 1;
        container.read(riverpod(i));
      }
    }, iterations: 1);

    benchmark('nesting', () {
      final container = ProviderContainer();
      container.read(nested).map(container.read);
    });
  });
}
