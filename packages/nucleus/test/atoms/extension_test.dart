import 'package:nucleus/nucleus.dart';
import 'package:test/test.dart';

void main() {
  group('select', () {
    test('returns a subset of the parent atom', () async {
      final userAtom = stateAtom({
        'id': 1,
        'name': 'Tim',
      });
      final nameAtom = userAtom.select((value) => value['name'] as String);
      final registry = AtomRegistry();

      final previousValues = <String?>[];
      final values = <String>[];

      registry.subscribeWithPrevious<String>(nameAtom, (prev, next) {
        previousValues.add(prev);
        values.add(next);
      }, fireImmediately: true);

      registry.set(userAtom, {'id': 2, 'name': 'Tim'});
      registry.set(userAtom, {'id': 2, 'name': 'John'});

      expect(
        previousValues,
        equals([null, 'Tim']),
      );

      expect(
        values,
        equals(['Tim', 'John']),
      );
    });

    test('does not rebuild if another property changes', () async {
      final userAtom = stateAtom({
        'id': 1,
        'name': 'Tim',
      });
      final idAtom = userAtom.select((user) => user['id'] as int);
      final nameAtom = userAtom.select((value) => value['name'] as String);

      final registry = AtomRegistry();

      var idValues = <int>[];
      var nameValues = <String>[];
      registry.subscribe(
        idAtom,
        (int id) => idValues.add(id),
        fireImmediately: true,
      );
      registry.subscribe(
        nameAtom,
        (String id) => nameValues.add(id),
        fireImmediately: true,
      );

      registry.set(userAtom, {'id': 2, 'name': 'Tim'});
      registry.set(userAtom, {'id': 2, 'name': 'John'});

      expect(idValues, equals([1, 2]));
      expect(nameValues, equals(['Tim', 'John']));
    });

    test('works with FutureValue', () async {
      final registry = AtomRegistry();

      final user = stateAtom({
        'id': 1,
        'name': 'Tim',
      });
      final futureUser = futureAtom((get) async {
        final value = get(user);
        await Future.microtask(() {});
        return value;
      });

      final id = futureUser.select((u) => u['id'] as int);
      final name = futureUser.select((u) => u['name'] as String);

      final idValues = <FutureValue<int>>[];
      registry.subscribe(id, idValues.add, fireImmediately: true);
      final nameValues = <FutureValue<String>>[];
      registry.subscribe(name, nameValues.add, fireImmediately: true);

      await Future.microtask(() {});
      registry.set(user, {'id': 1, 'name': 'John'});
      await Future.microtask(() {});

      expect(
        idValues,
        equals([
          FutureValue.loading(),
          FutureValue.data(1),
        ]),
      );

      expect(
        nameValues,
        equals([
          FutureValue.loading(),
          FutureValue.data('Tim'),
          FutureValue.data('John'),
        ]),
      );
    });
  });

  group('asyncSelect', () {
    test('only rebuilds when the selection changes', () async {
      final registry = AtomRegistry();

      final user = stateAtom({
        'id': 1,
        'name': 'Tim',
      });
      final futureUser = futureAtom((get) async {
        final value = get(user);
        await Future.microtask(() {});
        return value;
      });

      final id = futureAtom(
          (get) => get(futureUser.asyncSelect((u) => u['id'] as int)));
      final name = futureAtom(
          (get) => get(futureUser.asyncSelect((u) => u['name'] as String)));

      final idValues = <FutureValue<int>>[];
      registry.subscribe(id, idValues.add, fireImmediately: true);
      final nameValues = <FutureValue<String>>[];
      registry.subscribe(name, nameValues.add, fireImmediately: true);

      await Future.microtask(() {});
      registry.set(user, {'id': 1, 'name': 'John'});
      await Future.microtask(() {});
      await Future.microtask(() {});

      expect(
        idValues,
        equals([
          FutureValue.loading(),
          FutureValue.data(1),
        ]),
      );

      expect(
        nameValues,
        equals([
          FutureValue.loading(),
          FutureValue.data('Tim'),
          FutureValue.loading('Tim'),
          FutureValue.data('John'),
        ]),
      );
    });

    test('is refreshable', () async {
      final registry = AtomRegistry();

      var count = 1;
      final futureUser = futureAtom((get) async {
        await Future.microtask(() {});
        return {
          'id': count++,
          'name': 'Tim',
        };
      });

      final id = futureUser.select((u) => u['id'] as int).refreshable();
      final idValues = <FutureValue<int>>[];
      registry.subscribe(id, idValues.add, fireImmediately: true);

      await registry.get(futureUser.parent);

      expect(idValues, equals([FutureValue.loading(), FutureValue.data(1)]));

      registry.refresh(id);

      await registry.get(futureUser.parent);

      expect(
        idValues,
        equals([
          FutureValue.loading(),
          FutureValue.data(1),
          FutureValue.data(2),
        ]),
      );
    });
  });

  group('filter', () {
    test('it filters the values correctly', () async {
      final registry = AtomRegistry();

      final count = stateAtom(0);
      final evens = count.filter((i) => i.isEven);

      final values = <FutureValue<int>>[];
      registry.subscribe(evens, values.add, fireImmediately: true);

      registry.set(count, 1);
      registry.set(count, 2);
      registry.set(count, 3);
      registry.set(count, 4);

      expect(
        values,
        equals([FutureValue.data(0), FutureValue.data(2), FutureValue.data(4)]),
      );
    });

    test('it starts with FutureValue.loading if false', () async {
      final registry = AtomRegistry();

      final count = stateAtom(-1);
      final evens = count.filter((i) => i.isEven);

      final values = <FutureValue<int>>[];
      registry.subscribe(evens, values.add, fireImmediately: true);

      registry.set(count, 0);
      registry.set(count, 1);
      registry.set(count, 2);
      registry.set(count, 3);
      registry.set(count, 4);

      expect(
        values,
        equals([
          FutureValue.loading(),
          FutureValue.data(0),
          FutureValue.data(2),
          FutureValue.data(4)
        ]),
      );
    });
  });
}
