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

      final store = Store();

      expect(store.read(count), 0);
      expect(rebuilds, 1);
      expect(store.read(count), 0);
      expect(rebuilds, 1);

      store.put(count, null);
      expect(store.read(count), 0);
      expect(rebuilds, 2);
    });
  });
}
