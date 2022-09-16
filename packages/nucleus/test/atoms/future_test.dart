import 'dart:async';

import 'package:nucleus/nucleus.dart';
import 'package:test/test.dart';

final delayed123 = futureAtom((get) async {
  await Future.microtask(() {});
  return 123;
});

void main() {
  group('futureAtomTuple', () {
    test('returns a FutureValue', () async {
      final store = Store();

      expect(store.read(delayed123), FutureValue.loading());
      await store.read(delayed123.parent);
      expect(store.read(delayed123), FutureValue.data(123));
    });

    test('works with subscribe', () async {
      final store = Store();
      final c = StreamController<FutureValue<int>>();

      final cancel = store.subscribe(delayed123, () {
        c.add(store.read(delayed123));
      });

      expect(await c.stream.first, FutureValue.data(123));
      cancel();
    });

    test('loading state has previous data on refresh', () async {
      final store = Store();

      final count = stateAtom(0);
      final a = futureAtom((get) async {
        get(count);
        await Future.microtask(() {});
        return 123;
      });

      expect(store.read(a), FutureValue.loading());
      await store.read(a.parent);
      expect(store.read(a), FutureValue.data(123));

      store.put(count, 1);

      expect(store.read(a), FutureValue.loading(123));
      await store.read(a.parent);
      expect(store.read(a), FutureValue.data(123));
    });

    test('autoDispose works', () async {
      final store = Store();

      final a = futureAtom((get) async {
        await Future.microtask(() {});
        return 123;
      });

      expect(store.read(a), FutureValue.loading());
      await store.read(a.parent);
      expect(store.read(a), FutureValue.data(123));

      await Future.microtask(() {});
      expect(store.read(a), FutureValue.loading());
    });
  });
}
