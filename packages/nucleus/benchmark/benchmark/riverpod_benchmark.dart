import 'package:riverpod/riverpod.dart';

import 'utils.dart';

final value = Provider((ref) => 0);
final family = StateProvider.family((ref, int i) => i);
final nested = Provider((ref) => List.generate(
      10000,
      (i) => StateProvider.autoDispose((_) => i),
    ));
final nested100 = Provider((ref) => List.generate(
      100,
      (i) => StateProvider.autoDispose((_) => i),
    ));

final depZero = StateProvider((ref) => 0);
final depOne = Provider.autoDispose((ref) => ref.watch(value) * 10);
final depTwo = Provider.autoDispose((ref) => ref.watch(depOne) * 10);
final depThree = Provider.autoDispose((ref) => ref.watch(depTwo) * 10);

void main() {
  final benchmark = group('riverpod', ProviderContainer.new);

  benchmark('read 1000k', (container) {
    for (var i = 0; i < 1000000; i++) {
      container.read(value);
    }
  });

  benchmark('family state 100k', (container) {
    for (var i = 0; i < 100000; i++) {
      final provider = family(i);
      final notifier = container.read(provider.notifier);

      container.read(provider);
      notifier.state++;
      container.read(provider);
    }
  });

  benchmark('family state 10k', (container) {
    for (var i = 0; i < 10000; i++) {
      final provider = family(i);
      final notifier = container.read(provider.notifier);

      container.read(provider);
      notifier.state++;
      container.read(provider);
    }
  });

  benchmark('deps state 10k', (container) {
    for (var i = 0; i < 10000; i++) {
      final state = container.read(depZero);
      container.read(depZero.notifier).state = state + 1;
      container.read(depThree);
    }
  });

  benchmark('nesting 10k', (container) {
    container.read(nested).map(container.read).toList(growable: false);
  });

  benchmark('nesting 100', (container) {
    container.read(nested100).map(container.read).toList(growable: false);
  });
}
