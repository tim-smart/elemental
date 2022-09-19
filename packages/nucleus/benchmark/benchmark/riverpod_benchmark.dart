import 'package:benchmark/benchmark.dart';
import 'package:riverpod/riverpod.dart';

final value = Provider((ref) => 0);
final riverpod = StateProvider.family((ref, int i) => i);
final nested = Provider((ref) => List.generate(
      1000000,
      (i) => StateProvider.autoDispose((_) => i),
    ));

final depZero = StateProvider((ref) => 0);
final depOne = Provider((ref) => ref.watch(value) * 10);
final depTwo = Provider((ref) => ref.watch(depOne) * 10);
final depThree = Provider((ref) => ref.watch(depTwo) * 10);

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
        final notifier = container.read(riverpod(i).notifier);
        container.read(riverpod(i));
        notifier.state++;
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

    benchmark('deps state 10k', () {
      final container = ProviderContainer();
      for (var i = 0; i < 10000; i++) {
        container.read(depZero.notifier).update((i) => i + 1);
        container.read(depThree);
      }
    }, iterations: 1);

    benchmark('nesting 1000k', () {
      final container = ProviderContainer();
      container.read(nested).map(container.read);
    }, iterations: 1);
  });
}
