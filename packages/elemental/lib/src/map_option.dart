import 'package:elemental/elemental.dart';

extension ElementalMapExtension<K, V> on Map<K, V> {
  /// Return an [Option] that conditionally accesses map keys, if they match the
  /// given type.
  /// Useful for accessing nested JSON.
  ///
  /// ```
  /// expect(
  ///   { 'test': 123 }.extract<int>('test'),
  ///   some(123),
  /// );
  /// ```
  Option<T> extract<T>(K key) {
    final value = this[key];
    if (value is T) return Option.of(value);
    return Option.none();
  }

  /// Return an [Option] that conditionally accesses map keys, if they contain a map
  /// with the same key type.
  /// Useful for accessing nested JSON.
  ///
  /// ```
  /// expect(
  ///   { 'test': { 'foo': 'bar' } }.extractMap('test'),
  ///   some({ 'foo': 'bar' }),
  /// );
  /// ```
  Option<Map<K, dynamic>> extractMap(K key) => extract<Map<K, dynamic>>(key);
}

extension ElementalMapOptionExtension<K> on Option<Map<K, dynamic>> {
  /// Return an [Option] that conditionally accesses map keys, if they match the
  /// given type.
  /// Useful for accessing nested JSON.
  ///
  /// ```
  /// expect(
  ///   some({ 'test': 123 }).extract<int>('test'),
  ///   some(123),
  /// );
  /// ```
  Option<T> extract<T>(K key) => flatMap((map) => map.extract(key));

  /// Return an [Option] that conditionally accesses map keys, if they contain a map
  /// with the same key type.
  /// Useful for accessing nested JSON.
  ///
  /// ```
  /// expect(
  ///   some({ 'test': { 'foo': 'bar' } }).extractMap('test'),
  ///   some({ 'foo': 'bar' }),
  /// );
  /// ```
  Option<Map<K, dynamic>> extractMap(K key) => extract<Map<K, dynamic>>(key);
}
