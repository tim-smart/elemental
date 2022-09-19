import 'package:benchmark/benchmark.dart';
import 'package:nucleus/nucleus.dart';

final value = stateAtom(0)..keepAlive();
final nucleus = atomFamily((int i) => stateAtom(i));
final nested = atom((get) => List.generate(
      1000000,
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
  late AtomRegistry registry;

  setUpEach(() => registry = AtomRegistry());

  group('nucleus', () {
    benchmark('read 1000k', () {
      for (var i = 0; i < 1000000; i++) {
        registry.get(value);
      }
    }, iterations: 1);

    benchmark('state 100k', () {
      for (var i = 0; i < 100000; i++) {
        final atom = nucleus(i);
        final state = registry.get(atom);
        registry.set(atom, state + 1);
        registry.get(atom);
      }
    }, iterations: 1);

    benchmark('state 10k', () {
      for (var i = 0; i < 10000; i++) {
        final atom = nucleus(i);
        final state = registry.get(atom);
        registry.set(atom, state + 1);
        registry.get(atom);
      }
    }, iterations: 1);

    benchmark('deps state 10k', () {
      for (var i = 0; i < 10000; i++) {
        final state = registry.get(value);
        registry.set(value, state + 1);
        registry.get(depThree);
      }
    }, iterations: 1);

    benchmark('nesting 1000k', () {
      registry.get(nested).map(registry.get);
    }, iterations: 1);

    benchmark('nesting 100', () {
      registry.get(nested100).map(registry.get);
    }, iterations: 1);
  });
}
