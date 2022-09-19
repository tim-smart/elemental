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
  group('streamAtom', () {
    test('returns a FutureValue', () async {
      final store = AtomRegistry();
      final results = <FutureValue<int>>[];

      expect(store.get(delayed123), FutureValue.loading());

      final cancel = store.subscribe(delayed123, () {
        results.add(store.get(delayed123));
      });

      await store.get(delayed123.parent).last;
      cancel();

      expect(
        results,
        containsAllInOrder([
          FutureValue.loading(1),
          FutureValue.loading(2),
          FutureValue.loading(3),
          FutureValue.data(3),
        ]),
      );
    });

    test('auto dispose by default', () async {
      final store = AtomRegistry();

      expect(store.get(delayed123), FutureValue.loading());
      await store.get(delayed123.parent).first;
      expect(store.get(delayed123), FutureValue.loading());
    });

    test('keepAlive works', () async {
      final store = AtomRegistry();

      expect(store.get(delayed123KeepAlive), FutureValue.loading());
      await store.get(delayed123.parent).first;
      expect(store.get(delayed123KeepAlive), FutureValue.loading(1));
    });
  });
}
