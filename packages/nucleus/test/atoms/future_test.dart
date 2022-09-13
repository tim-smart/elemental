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

      await store.use(delayed123.first, () async {
        expect(store.read(delayed123.first), FutureValue.loading());
        await store.read(delayed123.second);
        expect(store.read(delayed123.first), FutureValue.data(123));
      });
    });
  });
}
