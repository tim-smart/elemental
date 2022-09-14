import 'dart:async';

import 'package:nucleus/nucleus.dart';
import 'package:test/test.dart';

final delayed123 = streamAtomTuple((get, _) async* {
  await Future.microtask(() {});
  yield 1;
  await Future.microtask(() {});
  yield 2;
  await Future.microtask(() {});
  yield 3;
});

void main() {
  group('streamAtomTuple', () {
    test('returns a FutureValue', () async {
      final store = Store();
      final results = <FutureValue<int>>[];

      expect(store.read(delayed123.first), FutureValue.loading());

      final cancel = store.subscribe(delayed123.first, () {
        results.add(store.read(delayed123.first));
      });

      await Future.delayed(Duration(milliseconds: 10));
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
  });
}
