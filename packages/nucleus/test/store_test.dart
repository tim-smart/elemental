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

      expect(store.read(counter), 0);
      expect(store.read(multiplied), 0);

      store.put(counter, 1);
      expect(store.read(counter), 1);
      expect(store.read(multiplied), 2);
    });

    test('initialValues are set', () {
      final store = Store(initialValues: [counter.withInitialValue(5)]);

      store.use(multiplied, () {
        expect(store.read(counter), 5);
        expect(store.read(multiplied), 10);
      });
    });

    test('it unmounts atoms if autoDispose() was called', () async {
      final stateMap = HashMap<int, AtomState>();
      final mountMap = HashMap<int, AtomMount>();
      final store = Store(stateMap: stateMap, mountMap: mountMap);

      await store.use(counterAutoDispose, () {
        expect(store.read(counterAutoDispose), 0);
        expect(mountMap.containsKey(counterAutoDispose.hashCode), true);
      });

      expect(mountMap.containsKey(counterAutoDispose.hashCode), false);

      // State is removed next frame
      expect(stateMap[counterAutoDispose.hashCode] != null, true);
      await Future.microtask(() {});
      expect(stateMap[counterAutoDispose.hashCode] != null, false);
    });

    test('state is kept between mounts if autoDispose is not called', () async {
      final stateMap = HashMap<int, AtomState>();
      final mountMap = HashMap<int, AtomMount>();
      final store = Store(stateMap: stateMap, mountMap: mountMap);

      await store.use(counter, () {
        expect(store.read(counter), 0);
        expect(mountMap.containsKey(counter.hashCode), true);
      });

      expect(mountMap.containsKey(counter.hashCode), false);

      expect(stateMap[counter.hashCode] != null, true);
      await Future.microtask(() {});
      expect(stateMap[counter.hashCode] != null, true);
    });

    test('onDispose is called on disposal', () async {
      final store = Store();

      var disposed = false;
      final atom = managedAtom(0, (ctx) => ctx.onDispose(() => disposed = true))
          .autoDispose();

      store.read(atom);

      expect(disposed, false);
      await Future.microtask(() {});
      expect(disposed, true);
    });

    test('onDispose is called on recalculation', () async {
      final store = Store();

      final count = atom(0);

      var disposed = false;
      final dependency = managedAtom(0, (x) {
        x.get(count);
        x.onDispose(() => disposed = true);
      });

      store.read(dependency);
      expect(disposed, false);
      store.put(count, 1);
      expect(disposed, true);
    });
  });
}
