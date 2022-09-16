import 'dart:async';
import 'dart:collection';

import 'package:nucleus/nucleus.dart';
import 'package:test/test.dart';

final counterKeepAlive = stateAtom(0)..keepAlive();
final counter = stateAtom(0);
final multiplied = atom((get) => get(counter) * 2);

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

      expect(store.read(counter), 5);
      expect(store.read(multiplied), 10);
    });

    test('it unmounts atoms if autoDispose() was called', () async {
      final stateMap = HashMap<Atom, AtomState>();
      final mountMap = HashMap<Atom, AtomMount>();
      final store = Store(stateMap: stateMap, mountMap: mountMap);

      await store.use(counter, () {
        expect(store.read(counter), 0);
        expect(mountMap.containsKey(counter), true);
      });

      expect(mountMap.containsKey(counter), false);

      // State is removed next frame
      expect(stateMap[counter] != null, true);
      await Future.microtask(() {});
      expect(stateMap[counter] != null, false);
    });

    test('state is kept between mounts if keepAlive is called', () async {
      final stateMap = HashMap<Atom, AtomState>();
      final mountMap = HashMap<Atom, AtomMount>();
      final store = Store(stateMap: stateMap, mountMap: mountMap);

      await store.use(counterKeepAlive, () {
        expect(store.read(counterKeepAlive), 0);
        expect(mountMap.containsKey(counterKeepAlive), true);
      });

      expect(mountMap.containsKey(counterKeepAlive), false);

      expect(stateMap[counterKeepAlive] != null, true);
      await Future.microtask(() {});
      expect(stateMap[counterKeepAlive] != null, true);
    });

    test('onDispose is called on disposal', () async {
      final store = Store();

      var disposed = false;
      final a = atom((get) => get.onDispose(() => disposed = true));

      store.read(a);

      expect(disposed, false);
      await Future.microtask(() {});
      expect(disposed, true);
    });

    test('autoDispose is set if onDispose is used', () async {
      final store = Store();

      var disposed = false;
      final a = atom((get) => get.onDispose(() => disposed = true));

      store.read(a);

      expect(disposed, false);
      await Future.microtask(() {});
      expect(disposed, true);
    });

    test('onDispose is called on recalculation', () async {
      final store = Store();

      final count = stateAtom(0);

      var disposed = false;
      final dependency = atom((get) {
        get(count);
        get.onDispose(() => disposed = true);
      });

      store.use(dependency, () {
        expect(disposed, false);
        store.put(count, 1);
        expect(disposed, true);
      });
    });

    test('throws an error if set is called after disposal', () async {
      final c = Completer.sync();

      final a = atom((x) {
        x.onDispose(() async {
          await Future.microtask(() {});
          expect(() => x.setSelf(1), throwsUnsupportedError);
          c.complete();
        });
        return 0;
      });

      final store = Store();
      store.read(a);
      await c.future;
    });
  });
}
