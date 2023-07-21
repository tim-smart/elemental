import 'dart:async';

import 'package:nucleus/nucleus.dart';
import 'package:test/test.dart';

final delayed123 = futureAtom((get) async {
  await Future.microtask(() {});
  return 123;
});

void main() {
  group('futureAtom', () {
    test('returns a FutureValue', () async {
      final store = AtomRegistry();

      await store.use(delayed123, () async {
        expect(store.get(delayed123), FutureValue.loading());
        await store.get(delayed123.parent);
        expect(store.get(delayed123), FutureValue.data(123));
      });
    });

    test('works with subscribe', () async {
      final store = AtomRegistry();
      final c = StreamController<FutureValue<int>>();

      final cancel = store.subscribe<FutureValue<int>>(delayed123, (value) {
        c.add(value);
      }, fireImmediately: true);

      expect(await c.stream.take(2).toList(), [
        FutureValue.loading(),
        FutureValue.data(123),
      ]);
      cancel();
    });

    test('loading state has previous data on refresh', () async {
      final store = AtomRegistry();

      final a = futureAtom((get) async {
        await Future.microtask(() {});
        return 123;
      }).refreshable();

      await store.use(a, () async {
        expect(store.get(a), FutureValue.loading());
        await store.get(a.parent);
        expect(store.get(a), FutureValue.data(123));

        store.refresh(a);

        expect(store.get(a), FutureValue.loading(123));
        await store.get(a.parent);
        expect(store.get(a), FutureValue.data(123));
      });
    });

    test('autoDispose works', () async {
      final store = AtomRegistry();

      final a = futureAtom((get) async {
        await Future.microtask(() {});
        return 123;
      });

      await store.use(a, () async {
        expect(store.get(a), FutureValue.loading());
        await store.get(a.parent);
        expect(store.get(a), FutureValue.data(123));
      });

      await Future.microtask(() {});
      expect(store.get(a), FutureValue.loading());
    });

    test('combineWith works', () async {
      final registry = AtomRegistry();
      final one = futureAtom((get) async {
        await Future.microtask(() {});
        return 1;
      });

      final two = futureAtom((get) async {
        await Future.delayed(Duration(milliseconds: 10));
        return 2;
      });

      final combined = atom((get) => get(one).combineWith(get(two)));

      final values = [];
      registry.subscribe(combined, values.add, fireImmediately: true);

      await registry.get(two.parent);

      expect(
        values,
        equals([
          FutureValue.loading(),
          FutureValue.data((1, 2)),
        ]),
      );
    });
  });
}
