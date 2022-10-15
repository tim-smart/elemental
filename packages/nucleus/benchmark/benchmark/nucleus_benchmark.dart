import 'package:nucleus/nucleus.dart';

import 'utils.dart';

final value = stateAtom(0);
final valueKeepAlive = stateAtom(0).keepAlive();
final family = atomFamily((int i) => stateAtom(i));
final familyWeak = weakAtomFamily((int i) => stateAtom(i));
final nested = atom((get) => List.generate(
      10000,
      (i) => stateAtom(i),
    ));
final nested100 = atom((get) => List.generate(
      100,
      (i) => stateAtom(i),
    ));

final depOne = atom((get) => get(value) * 10);
final depTwo = atom((get) => get(depOne) * 10);
final depThree = atom((get) => get(depTwo) * 10);

void main() {
  final benchmark = group('nucleus', AtomRegistry.new);

  benchmark('read 1000k', (registry) {
    for (var i = 0; i < 1000000; i++) {
      registry.get(value);
    }
  });

  benchmark('read keepAlive 1000k', (registry) {
    for (var i = 0; i < 1000000; i++) {
      registry.get(valueKeepAlive);
    }
  });

  benchmark('family read 100k', (registry) {
    for (var i = 0; i < 100000; i++) {
      registry.get(family(i));
    }
  });

  benchmark('family state 100k', (registry) {
    for (var i = 0; i < 100000; i++) {
      final atom = family(i);
      final state = registry.get(atom);
      registry.set(atom, state + 1);
      registry.get(atom);
    }
  });

  benchmark('family state 100k weak', (registry) {
    for (var i = 0; i < 100000; i++) {
      final atom = familyWeak(i);
      final state = registry.get(atom);
      registry.set(atom, state + 1);
      registry.get(atom);
    }
  });

  benchmark('deps state 10k', (registry) {
    for (var i = 0; i < 10000; i++) {
      final state = registry.get(value);
      registry.set(value, state + 1);
      registry.get(depThree);
    }
  });

  benchmark('nesting 10k', (registry) {
    registry.get(nested).map(registry.get).toList(growable: false);
  });

  benchmark('nesting 100', (registry) {
    registry.get(nested100).map(registry.get).toList(growable: false);
  });
}
