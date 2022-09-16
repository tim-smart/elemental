import 'package:nucleus/nucleus.dart';
import 'package:test/test.dart';

void main() {
  group('ProxyAtom', () {
    test('writes to the parent', () {
      final count = stateAtom(0);
      final proxy = proxyAtom(
        (get) => get(count) * 10,
        (get, set, int value) => set(count, value),
      );

      final store = AtomRegistry();

      expect(store.get(proxy), 0);
      store.set(proxy, 1);
      expect(store.get(proxy), 10);
    });

    test('can proxy writes', () {
      final count = stateAtom(0);
      final proxy = proxyAtom(
        (get) => get(count),
        (get, set, int i) => set(count, i * 10),
      );

      final store = AtomRegistry();

      expect(store.get(proxy), 0);
      store.set(proxy, 1);
      expect(store.get(proxy), 10);
    });

    test('can get parent in writer', () {
      final count = stateAtom(0);
      final proxy = proxyAtom(
        (get) => get(count),
        (get, set, void _) => set(count, get(count) + 1),
      );

      final store = AtomRegistry();

      expect(store.get(proxy), 0);
      store.set(proxy, null);
      expect(store.get(proxy), 1);
    });
  });
}
