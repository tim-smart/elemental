import 'package:nucleus/nucleus.dart';
import 'package:test/test.dart';

final counter = atom(0);
final multiplied = derivedAtom((get) => get(counter) * 2);

void main() {
  group('Store', () {
    test('it reads and writes', () {
      final store = Store();

      store.use(multiplied, () {
        expect(store.read(counter), 0);
        expect(store.read(multiplied), 0);

        store.put(counter, 1);
        expect(store.read(counter), 1);
        expect(store.read(multiplied), 2);
      });
    });

    test('initialValues are set', () {
      final store = Store(initialValues: [counter.withInitialValue(5)]);

      store.use(multiplied, () {
        expect(store.read(counter), 5);
        expect(store.read(multiplied), 10);
      });
    });
  });
}
