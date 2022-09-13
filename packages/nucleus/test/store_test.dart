import 'dart:collection';

import 'package:nucleus/nucleus.dart';
import 'package:test/test.dart';

final counter = atom(0);
final counterAutoDispose = atom(0).autoDispose();
final multiplied = readOnlyAtom((get) => get(counter) * 2);

void main() {
  group('Store', () {
    test('it reads and writes', () {
      final store = Store();

      store.use(multiplied, () {
        expect(store.read(counter), 0);
        expect(store.read(multiplied), 0);

        store.put(counter, 1);
        expect(store.read(counter), 1);
        expect(store.read(multiplied), 2);
      });
    });

    test('initialValues are set', () {
      final store = Store(initialValues: [counter.withInitialValue(5)]);

      store.use(multiplied, () {
        expect(store.read(counter), 5);
        expect(store.read(multiplied), 10);
      });
    });

    test('it unmounts atoms if autoDispose() was called', () async {
      final stateMap = HashMap<Atom, AtomState>();
      final mountMap = HashMap<Atom, AtomMount>();
      final store = Store(stateMap: stateMap, mountMap: mountMap);

      await store.use(counterAutoDispose, () {
        expect(store.read(counterAutoDispose), 0);
        expect(mountMap.containsKey(counterAutoDispose), true);
      });

      expect(mountMap.containsKey(counterAutoDispose), false);

      // State is removed next frame
      expect(stateMap.containsKey(counterAutoDispose), true);
      await Future.microtask(() {});
      expect(stateMap.containsKey(counterAutoDispose), false);
    });

    test('state is kept between mounts if autoDispose is not called', () async {
      final stateMap = HashMap<Atom, AtomState>();
      final mountMap = HashMap<Atom, AtomMount>();
      final store = Store(stateMap: stateMap, mountMap: mountMap);

      await store.use(counter, () {
        expect(store.read(counter), 0);
        expect(mountMap.containsKey(counter), true);
      });

      expect(mountMap.containsKey(counter), false);

      // State is removed next frame
      expect(stateMap.containsKey(counter), true);
      await Future.microtask(() {});
      expect(stateMap.containsKey(counter), true);
    });

    test('onDispose is called on disposal', () async {
      final store = Store();

      var disposed = false;
      final atom = managedAtom(0, (ctx) => ctx.onDispose(() => disposed = true))
          .autoDispose();

      await store.use(atom, () {});

      expect(disposed, false);
      await Future.microtask(() {});
      expect(disposed, true);
    });

    test('onDispose is called on recalculation', () async {
      final store = Store();

      final count = atom(0);

      var disposed = false;
      final dependency = managedAtom(0, (ctx) {
        ctx.get(count);
        ctx.onDispose(() => disposed = true);
      });

      await store.use(dependency, () {
        expect(disposed, false);
        store.put(count, 1);
        expect(disposed, true);
      });
    });
  });
}
