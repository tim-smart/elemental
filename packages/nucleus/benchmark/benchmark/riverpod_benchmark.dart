import 'package:benchmark/benchmark.dart';
import 'package:riverpod/riverpod.dart';

final riverpod = StateProvider.family((ref, int i) => i);
final nested = Provider((ref) => List.generate(
      100000,
      (i) => StateProvider.autoDispose((_) => i),
    ));

void main() {
  group('riverpod', () {
    benchmark('100k', () {
      final container = ProviderContainer();
      for (var i = 0; i < 100000; i++) {
        final state = container.read(riverpod(i));
        container.read(riverpod(i).notifier).state = state + 1;
        container.read(riverpod(i));
      }
    }, iterations: 1);

    benchmark('10k', () {
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
