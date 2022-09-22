import 'package:nucleus/nucleus.dart';
import 'package:test/test.dart';

void main() {
  group('Registry', () {
    test('it adds a node on get', () {
      final r = AtomRegistry();
      final atom = stateAtom(0);

      expect(r.get(atom), 0);
      expect(r.nodes[atom] != null, true);
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
      expect(r.nodes[atom] != null, true);

      await Future.microtask(() {});

      expect(r.nodes[atom] != null, false);
    });

    test('subscribe listens for changes and keeps node alive', () async {
      final r = AtomRegistry();
      final atom = stateAtom(0);

      var counter = 0;
      final cancel = r.subscribe(atom, (_) {
        counter++;
      });

      r.set(atom, 1);
      r.set(atom, 2);
      expect(counter, 2);

      // Keep alive
      await Future.microtask(() {});
      expect(r.nodes[atom] != null, true);

      // cancel
      cancel();
      await Future.microtask(() {});
      expect(r.nodes[atom] != null, false);
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

    test('initialValues override values', () {
      final a = atom<int>((get) => throw UnimplementedError());
      final r = AtomRegistry(initialValues: [a.withInitialValue(123)]);
      expect(r.get(a), 123);
    });

    test('dependencies are not orphaned', () async {
      final count = stateAtom(0)..keepAlive();
      final selectAtoms = <Atom<int>>[];
      final derived = atom((get) {
        final plusOne = count.select((i) => i + 1);
        selectAtoms.add(plusOne);
        return get(plusOne) * 2;
      });

      final r = AtomRegistry();

      await r.use(derived, () async {
        expect(r.get(derived), 2);

        await Future.microtask(() {});

        r.set(count, 1);
        expect(r.get(derived), 4);
      });

      await Future.microtask(() {});

      expect(r.nodes[count] != null, true);
      expect(r.nodes[derived] == null, true);

      for (final a in selectAtoms) {
        expect(r.nodes[a] == null, true);
      }
    });
  });

  group('subscribeWithPrevious', () {
    test('it emits the latest values if they change', () async {
      final count = stateAtom(0);
      final registry = AtomRegistry();

      final previousValues = <int?>[];
      final values = <int>[];
      registry.subscribeWithPrevious<int>(count, (previous, value) {
        previousValues.add(previous);
        values.add(value);
      });

      registry.set(count, 1);
      registry.set(count, 1);
      registry.set(count, 2);

      expect(
        previousValues,
        equals([null, 1]),
      );

      expect(
        values,
        equals([1, 2]),
      );
    });
  });
}
