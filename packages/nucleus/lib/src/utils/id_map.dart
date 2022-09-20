import 'package:nucleus/nucleus.dart';

Map<Id, A> Function(Iterable<T> items) atomIdMap<T, Id, A extends Atom<T>>(
  A Function(T item) create, {
  required Id Function(T item) id,
}) =>
    (items) {
      final map = <Id, A>{};
      for (final item in items) {
        map[id(item)] = create(item);
      }
      return map;
    };
