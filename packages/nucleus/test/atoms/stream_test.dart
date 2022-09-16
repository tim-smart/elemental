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

final delayed123KeepAlive = streamAtom((get) async* {
  await Future.microtask(() {});
  yield 1;
  await Future.microtask(() {});
  yield 2;
  await Future.microtask(() {});
  yield 3;
})
  ..keepAlive();

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

    test('auto dispose by default', () async {
      final store = Store();

      expect(store.read(delayed123), FutureValue.loading());
      await store.read(delayed123.parent).first;
      expect(store.read(delayed123), FutureValue.loading());
    });

    test('keepAlive works', () async {
      final store = Store();

      expect(store.read(delayed123KeepAlive), FutureValue.loading());
      await store.read(delayed123.parent).first;
      expect(store.read(delayed123KeepAlive), FutureValue.data(1));
    });
  });
}
