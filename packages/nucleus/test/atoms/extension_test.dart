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
  });
}
