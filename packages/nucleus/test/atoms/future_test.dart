import 'dart:async';

import 'package:nucleus/nucleus.dart';
import 'package:test/test.dart';

final delayed123 = futureAtomTuple((_) async {
  await Future.microtask(() {});
  return 123;
});

void main() {
  group('futureAtomTuple', () {
    test('returns a FutureValue', () async {
      final store = Store();

      expect(store.read(delayed123.first), FutureValue.loading());
      await store.read(delayed123.second);
      expect(store.read(delayed123.first), FutureValue.data(123));
    });

    test('works with subscribe', () async {
      final store = Store();
      final c = StreamController<FutureValue<int>>();

      final cancel = store.subscribe(delayed123.first, () {
        c.add(store.read(delayed123.first));
      });

      expect(await c.stream.first, FutureValue.data(123));
      cancel();
    });
  });
}
