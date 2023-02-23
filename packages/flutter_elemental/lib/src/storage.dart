import 'package:flutter_elemental/flutter_elemental.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageError {
  const StorageError(this.error);
  final dynamic error;
}

final sharedPrefsLayer = Layer.memoize(EIO.tryCatch(
  () => SharedPreferences.getInstance(),
  (error, stack) => StorageError(error),
));

final storageLayer = Layer<StorageError, NucleusStorage>.memoize(
  EIO.layer(sharedPrefsLayer).map((_) => SharedPrefsStorage(_)),
);

class StorageRef<A> extends Ref<A> {
  StorageRef._(
    A initialValue, {
    required this.storage,
    required this.key,
    required this.fromJson,
    required this.toJson,
  }) : super.unsafeMake(_decode(storage, key, initialValue, fromJson));

  static A _decode<A>(
    NucleusStorage storage,
    String key,
    A initialValue,
    A Function(dynamic json) fromJson,
  ) {
    try {
      final storedValue = storage.get(key);
      if (storedValue != null) {
        return fromJson(storedValue);
      }
    } catch (err) {
      assert(() {
        // ignore: use_rethrow_when_possible
        throw err;
      }());
    }

    return initialValue;
  }

  static ZIO<R, StorageError, StorageRef<A>> make<R extends ScopeMixin, A>(
    A initialValue, {
    required String key,
    required A Function(dynamic json) fromJson,
    required dynamic Function(A a) toJson,
  }) =>
      ZIO<R, StorageError, NucleusStorage>.layer(storageLayer).map(
        (storage) => StorageRef._(
          initialValue,
          storage: storage,
          key: key,
          fromJson: fromJson,
          toJson: toJson,
        ),
      );

  static ZIO<Scope, StorageError, StorageRef<A>> makeScope<A>(
    A initialValue, {
    required String key,
    required A Function(dynamic json) fromJson,
    required dynamic Function(A a) toJson,
  }) =>
      make(initialValue, key: key, fromJson: fromJson, toJson: toJson);

  final NucleusStorage storage;
  final String key;
  final A Function(dynamic json) fromJson;
  final dynamic Function(A a) toJson;

  @override
  void unsafeValueDidChange(A value) {
    super.unsafeValueDidChange(value);
    storage.set(key, toJson(value));
  }
}
