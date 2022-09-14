import 'package:nucleus/nucleus.dart';
import 'package:test/test.dart';

void main() {
  group('ProxyAtom', () {
    test('writes to the parent', () {
      final count = atom(0);
      final proxy = proxyAtom(count, (get) => get(count) * 10);

      final store = Store();

      expect(store.read(proxy), 0);
      store.put(proxy, 1);
      expect(store.read(proxy), 10);
    });

    test('can proxy writes', () {
      final count = atom(0);
      final proxy = proxyAtomWithWriter(
        count,
        (get) => get(count),
        (int value, get) => value * 10,
      );

      final store = Store();

      expect(store.read(proxy), 0);
      store.put(proxy, 1);
      expect(store.read(proxy), 10);
    });

    test('can get parent in writer', () {
      final count = atom(0);
      final proxy = proxyAtomWithWriter(
        count,
        (get) => get(count),
        (void _, get) => get(count) + 1,
      );

      final store = Store();

      expect(store.read(proxy), 0);
      store.put(proxy, null);
      expect(store.read(proxy), 1);
    });
  });
}
