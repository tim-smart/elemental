import 'package:benchmark/benchmark.dart';
import 'package:riverpod/riverpod.dart';

final riverpod = StateProvider.family((ref, int i) => i);
final nested = Provider((ref) => List.generate(
      100000,
      (i) => StateProvider.autoDispose((_) => i),
    ));

void main() {
  group('riverpod', () {
    benchmark('1000k', () {
      final container = ProviderContainer();
      for (var i = 0; i < 1000000; i++) {
        final state = container.read(riverpod(i));
        container.read(riverpod(i).notifier).state = state + 1;
        container.read(riverpod(i));
      }
    }, iterations: 3);

    benchmark('nesting', () {
      final container = ProviderContainer();
      container.read(nested).map(container.read);
    });
  });
}
