import 'package:nucleus/nucleus.dart';
import 'package:test/test.dart';

void main() {
  group('keepAlive', () {
    test('sets keepAlive on parent', () {
      final a = atomWithParent(
        atom((get) => 1),
        (get, Atom<int> parent) => get(parent),
      ).keepAlive();

      expect(a.parent.shouldKeepAlive, true);
    });
  });
}
