import 'package:nucleus/nucleus.dart';
import 'package:test/test.dart';

void main() {
  group('atomFamily', () {
    test('it points to the same atom on multiple calls', () async {
      final family = atomFamily((int id) => stateAtom(id));
      final registry = AtomRegistry();

      expect(registry.get(family(1)), 1);
      registry.set(family(1), 2);
      expect(registry.get(family(1)), 2);

      // Wait for GC
      await Future.microtask(() => null);

      expect(registry.get(family(1)), 1);
    });

    test('keepAlive works', () async {
      final family = atomFamily((int id) => stateAtom(id)..keepAlive());
      final registry = AtomRegistry();

      registry.set(family(1), 2);

      // Wait for GC
      await Future.microtask(() => null);

      expect(registry.get(family(1)), 2);
    });

    test('atom identity changes after disposal', () async {
      final family = atomFamily((int id) => stateAtom(id));
      final registry = AtomRegistry();

      final before = family(1);
      expect(before == family(1), true);
      registry.set(family(1), 2);

      // Wait for GC
      await Future.microtask(() => null);

      final after = family(1);
      expect(registry.get(family(1)), 1);
      expect(before == after, false);
    });
  });

  group('atoms in atom', () {
    test('list is rebuilt on parent change', () async {
      final itemCount = stateAtom(10);
      final items = atom((get) => List.generate(
            get(itemCount),
            (i) => stateAtom(i)..keepAlive(),
          ));
      final registry = AtomRegistry();

      expect(registry.get(items).length, 10);
      expect(registry.get(items).map(registry.get).last, 9);

      // Keep alive works
      await Future.microtask(() => null);
      expect(registry.get(items).map(registry.get).last, 9);

      // Uncomment these lines to check if the atoms have been GC'ed.
      // You can inspect the internal Expando _data property in the registry.
      // await Future.delayed(Duration(seconds: 5));
      // debugger();

      // Create new list
      registry.set(itemCount, 20);
      expect(registry.get(items).length, 20);
      expect(registry.get(items).map(registry.get).last, 19);
    });
  });
}
