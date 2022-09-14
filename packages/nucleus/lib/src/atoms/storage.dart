import 'dart:collection';

import 'package:nucleus/nucleus.dart';

abstract class NucleusStorage {
  Object? get(String key);
  void set(String key, Object? value);
}

class MemoryNucleusStorage implements NucleusStorage {
  final _map = HashMap<String, Object?>();

  @override
  Object? get(String key) => _map[key];

  @override
  void set(String key, Object? value) {
    _map[key] = value;
  }
}

Atom<A, A> atomWithStorage<A>(
  String key,
  A initialValue, {
  required Atom<NucleusStorage, dynamic> storage,
  required A Function(dynamic json) fromJson,
  required dynamic Function(A a) toJson,
}) {
  final valueAtom = atom<A?>(null);

  return ProxyAtom(valueAtom, (get) {
    final value = get(valueAtom);
    if (value != null) {
      return value;
    }

    final storedValue = get(storage).get(key);
    return storedValue != null ? fromJson(storedValue) : initialValue;
  }, (value, get) {
    get(storage).set(key, toJson(value));
    return value;
  });
}

typedef AtomWithStorageCreate<R, A> = R Function(
  AtomGetter get,
  A? Function() read,
  void Function(A value) write,
);

Atom<R, void> readOnlyAtomWithStorage<R, A>(
  String key,
  AtomWithStorageCreate<R, A> create, {
  required Atom<NucleusStorage, dynamic> storage,
  required A Function(dynamic json) fromJson,
  required dynamic Function(A a) toJson,
}) =>
    readOnlyAtom((get) {
      final s = get(storage);

      void write(A value) => s.set(key, toJson(value));

      A? read() {
        final value = s.get(key);
        return value != null ? fromJson(value) : null;
      }

      return create(get, read, write);
    });
