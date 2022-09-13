import 'package:benchmark/benchmark.dart';
import 'package:riverpod/riverpod.dart';

final parent = Provider((ref) => 0);
final riverpod = StateProvider.family((ref, int i) => ref.watch(parent) + i);

void main() {
  group('riverpod', () {
    benchmark('100k', () {
      final container = ProviderContainer();
      for (var i = 0; i < 100000; i++) {
        final state = container.read(riverpod(i));
        container.read(riverpod(i).notifier).update((i) => i + 1);
        final newState = container.read(riverpod(i));
      }
    });
  });
}
