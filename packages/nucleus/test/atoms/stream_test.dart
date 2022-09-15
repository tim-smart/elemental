import 'dart:async';

import 'package:nucleus/nucleus.dart';
import 'package:test/test.dart';

final delayed123 = streamAtom((get) async* {
  await Future.microtask(() {});
  yield 1;
  await Future.microtask(() {});
  yield 2;
  await Future.microtask(() {});
  yield 3;
});

final delayed123Dispose = streamAtom((get) async* {
  await Future.microtask(() {});
  yield 1;
  await Future.microtask(() {});
  yield 2;
  await Future.microtask(() {});
  yield 3;
})
  ..autoDispose();

void main() {
  group('streamAtomTuple', () {
    test('returns a FutureValue', () async {
      final store = Store();
      final results = <FutureValue<int>>[];

      expect(store.read(delayed123), FutureValue.loading());

      final cancel = store.subscribe(delayed123, () {
        results.add(store.read(delayed123));
      });

      await store.read(delayed123.parent).last;
      cancel();

      expect(
        results,
        containsAllInOrder([
          FutureValue.data(1),
          FutureValue.data(2),
          FutureValue.data(3),
        ]),
      );
    });

    test('keepAlive by default', () async {
      final store = Store();

      expect(store.read(delayed123), FutureValue.loading());
      await store.read(delayed123.parent).first;
      expect(store.read(delayed123), FutureValue.data(1));
      await store.read(delayed123.parent).last;
      expect(store.read(delayed123), FutureValue.data(3));
    });

    test('autoDispose works', () async {
      final store = Store();

      expect(store.read(delayed123Dispose), FutureValue.loading());
      await Future.microtask(() {});
      expect(store.read(delayed123Dispose), FutureValue.loading());
    });
  });
}
