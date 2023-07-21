import 'dart:developer';

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
      final family = atomFamily((int id) => stateAtom(id).keepAlive());
      final registry = AtomRegistry();

      registry.set(family(1), 2);

      // Wait for GC
      await Future.microtask(() => null);

      expect(registry.get(family(1)), 2);
    });

    test('atom identity does not change after disposal', () async {
      final family = atomFamily((int id) => stateAtom(id));
      final registry = AtomRegistry();

      final before = family(1);
      expect(before == family(1), true);
      registry.set(family(1), 2);

      // Wait for GC
      await Future.microtask(() => null);

      final after = family(1);
      expect(registry.get(family(1)), 1);
      expect(before == after, true);
    });
  });

  group('weakAtomFamily', () {
    test('allows keepAlive atoms to be GCed', () async {
      final family = weakAtomFamily((int id) => stateAtom(id).keepAlive());
      final registry = AtomRegistry();

      expect(registry.get(family(1)), 1);
      registry.set(family(1), 2);
      expect(registry.get(family(1)), 2);

      // Wait for GC
      // TODO: find a way to force GC
      // await Future.delayed(Duration(seconds: 3));
      // expect(registry.get(family(1)), 1);
    });
  });

  group('atoms in atom', () {
    test('list is rebuilt on parent change', () async {
      final itemCount = stateAtom(10);
      final items = atom((get) => List.generate(
            get(itemCount),
            (i) => stateAtom(i).keepAlive(),
          )).keepAlive();

      final registry = AtomRegistry();

      expect(registry.get(items).length, 10);
      expect(registry.get(items).map(registry.get).last, 9);

      // Keep alive works
      await Future.microtask(() => null);
      expect(registry.get(items).map(registry.get).last, 9);

      // Create new list
      registry.set(itemCount, 20);
      expect(registry.get(items).length, 20);
      expect(registry.get(items).map(registry.get).last, 19);

      // Uncomment these lines to check if the atoms have been GC'ed.
      // You can inspect the internal Expando _data property in the registry.
      // await Future.delayed(Duration(seconds: 5));
      // debugger();

      // Keep alive works for new list
      await Future.microtask(() => null);
      expect(registry.get(items).map(registry.get).last, 19);
    });
  });

  group('atomFamily 2 args', () {
    test('it points to the same atom on multiple calls', () async {
      final family = atomFamily(((int id, String name) args) => stateAtom({
            'id': args.$1,
            'name': args.$2,
          }));
      final registry = AtomRegistry();

      expect(
          registry.get(family((1, 'Tim'))), equals({'id': 1, 'name': 'Tim'}));
      registry.set(family((1, 'Tim')), {'id': 1, 'name': 'John'});
      expect(
          registry.get(family((1, 'Tim'))), equals({'id': 1, 'name': 'John'}));

      // Wait for GC
      await Future.microtask(() => null);

      expect(
          registry.get(family((1, 'Tim'))), equals({'id': 1, 'name': 'Tim'}));
    });
  });
}
