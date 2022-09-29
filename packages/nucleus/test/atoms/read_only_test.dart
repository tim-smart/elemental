import 'dart:async';

import 'package:nucleus/nucleus.dart';
import 'package:test/test.dart';

void main() {
  group('ReadOnlyAtom', () {
    test('can refreshSelf', () async {
      final registry = AtomRegistry();
      final c = StreamController.broadcast();

      var count = 0;
      final a = atom((get) {
        c.stream.first.then((_) => get.refreshSelf());
        return count++;
      })
        ..keepAlive();

      expect(registry.get(a), 0);
      expect(registry.get(a), 0);
      c.add(null);
      await Future.microtask(() {});
      expect(registry.get(a), 1);
      c.add(null);
      await Future.microtask(() {});
      expect(registry.get(a), 2);
    });
  });
}
