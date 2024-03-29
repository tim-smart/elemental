import 'package:creator_core/creator_core.dart';

import 'utils.dart';

final value = Creator.value(0);
final valueKeepAlive = Creator.value(0, keepAlive: true);
Creator<int> family(int i) => Creator.value(i);
final nested = Creator((ref) => List.generate(10000, (i) => Creator.value(i)));
final nested100 = Creator((ref) => List.generate(100, (i) => Creator.value(i)));

final depOne = Creator((ref) => ref.watch(value) * 10);
final depTwo = Creator((ref) => ref.watch(depOne) * 10);
final depThree = Creator((ref) => ref.watch(depTwo) * 10);

void main() {
  final benchmark = group('creator', Ref.new);

  benchmark('read 1000k', (ref) {
    for (var i = 0; i < 1000000; i++) {
      ref.read(value);
    }
  });

  benchmark('read keepAlive 1000k', (ref) {
    for (var i = 0; i < 1000000; i++) {
      ref.read(valueKeepAlive);
    }
  });

  benchmark('family read 100k', (ref) {
    for (var i = 0; i < 100000; i++) {
      ref.read(family(i));
    }
  });

  benchmark('family state 100k', (ref) {
    for (var i = 0; i < 100000; i++) {
      final c = family(i);
      final state = ref.read(c);
      ref.set(c, state + 1);
      ref.read(c);
    }
  });

  benchmark('deps state 10k', (ref) {
    for (var i = 0; i < 10000; i++) {
      final state = ref.read(value);
      ref.set(value, state + 1);
      ref.read(depThree);
    }
  });

  benchmark('nesting 10k', (ref) {
    ref.read(nested).map(ref.read).toList(growable: false);
  });

  benchmark('nesting 100', (ref) {
    ref.read(nested100).map(ref.read).toList(growable: false);
  });
}
