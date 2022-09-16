import 'package:nucleus/nucleus.dart';
import 'package:test/test.dart';

void main() {
  group('atomWithRefresh', () {
    test('rebuilds the value on write', () {
      var rebuilds = 0;

      final count = atomWithRefresh((get) {
        rebuilds++;
        return 0;
      });

      final store = AtomRegistry();

      expect(store.get(count), 0);
      expect(rebuilds, 1);
      expect(store.get(count), 0);
      expect(rebuilds, 1);

      store.set(count, null);
      expect(store.get(count), 0);
      expect(rebuilds, 2);
    });
  });
}
