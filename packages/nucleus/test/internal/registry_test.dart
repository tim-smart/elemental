import 'package:nucleus/nucleus.dart';
import 'package:test/test.dart';

void main() {
  group('Registry', () {
    test('it adds a node on get', () {
      final r = AtomRegistry();
      final atom = stateAtom(0);

      expect(r.get(atom), 0);
      expect(r.nodes.containsKey(atom), true);
    });

    test('set updates the value', () {
      final r = AtomRegistry();
      final atom = stateAtom(0);

      r.set(atom, 1);
      expect(r.get(atom), 1);
    });

    test('it automatically disposes unused nodes', () async {
      final r = AtomRegistry();
      final atom = stateAtom(0);

      expect(r.get(atom), 0);
      expect(r.nodes.containsKey(atom), true);

      await Future.microtask(() {});

      expect(r.nodes.containsKey(atom), false);
    });

    test('subscribe listens for changes and keeps node alive', () async {
      final r = AtomRegistry();
      final atom = stateAtom(0);

      var counter = 0;
      final cancel = r.subscribe(atom, () {
        counter++;
      });

      r.set(atom, 1);
      r.set(atom, 2);
      expect(counter, 2);

      // Keep alive
      await Future.microtask(() {});
      expect(r.nodes.containsKey(atom), true);

      // cancel
      cancel();
      await Future.microtask(() {});
      expect(r.nodes.containsKey(atom), false);
    });

    test('dependencies are updated', () {
      final r = AtomRegistry();
      final count = stateAtom(0);
      final multiplied = atom((get) => get(count) * 2);

      expect(r.get(count), 0);
      expect(r.get(multiplied), 0);

      r.set(count, 1);
      expect(r.get(multiplied), 2);
    });

    test('onDispose is called', () async {
      final r = AtomRegistry();
      var disposed = false;
      final zero = atom((_) {
        _.onDispose(() {
          disposed = true;
        });
        return 0;
      });

      r.get(zero);

      await Future.microtask(() => null);

      expect(disposed, true);
    });

    test('can setSelf inside an atom', () async {
      final r = AtomRegistry();
      final zero = atom((_) {
        _.setSelf(1);
        _.setSelf(2);
        return 0;
      });

      expect(r.get(zero), 2);
    });

    test('set throws an error after onDispose is called', () async {
      final r = AtomRegistry();
      var disposed = false;
      final zero = atom<int>((_) {
        _.onDispose(() {
          disposed = true;
        });
        return 0;
      });

      r.get(zero);

      await Future.microtask(() => null);

      expect(disposed, true);
    });
  });
}
