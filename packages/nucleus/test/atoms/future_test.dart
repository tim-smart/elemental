import 'dart:async';

import 'package:nucleus/nucleus.dart';
import 'package:test/test.dart';

final delayed123 = futureAtom((get, _) async {
  await Future.microtask(() {});
  return 123;
});

void main() {
  group('futureAtomTuple', () {
    test('returns a FutureValue', () async {
      final store = Store();

      expect(store.read(delayed123), FutureValue.loading());
      await store.read(delayed123.future);
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
  });
}
