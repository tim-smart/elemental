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
