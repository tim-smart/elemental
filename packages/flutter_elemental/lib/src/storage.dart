import 'package:flutter_elemental/flutter_elemental.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPrefsError {
  const SharedPrefsError(this.error);
  final dynamic error;
}

final sharedPrefsLayer = Layer(EIO.tryCatch(
  () => SharedPreferences.getInstance(),
  (error, stack) => SharedPrefsError(error),
));

/// A storage interface that can be implemented by different storage backends.
///
/// The default implementation uses [SharedPreferences].
final storageLayer = Layer(
  sharedPrefsLayer.accessWith<NucleusStorage>(SharedPrefsStorage.new),
);

/// A [NucleusStorage] implementation that uses [MemoryNucleusStorage].
final memoryStorageLayer = storageLayer.replace(IO(MemoryNucleusStorage.new));

/// A variant of [Ref], that stores its value in a [NucleusStorage].
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

  static ZIO<R, SharedPrefsError, Ref<A>> makeWith<R extends ScopeMixin, A>(
    A initialValue, {
    required String key,
    required A Function(dynamic json) fromJson,
    required dynamic Function(A a) toJson,
  }) =>
      ZIO<R, SharedPrefsError, NucleusStorage>.layer(storageLayer).map(
        (storage) => StorageRef._(
          initialValue,
          storage: storage,
          key: key,
          fromJson: fromJson,
          toJson: toJson,
        ),
      );

  static ZIO<Scope<NoEnv>, SharedPrefsError, Ref<A>> make<A>(
    A initialValue, {
    required String key,
    required A Function(dynamic json) fromJson,
    required dynamic Function(A a) toJson,
  }) =>
      makeWith(initialValue, key: key, fromJson: fromJson, toJson: toJson);

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
