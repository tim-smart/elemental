import 'package:elemental/elemental.dart';

extension ElementalOptionExt<A> on Option<A> {
  /// Return a new [Option] that calls [Option.fromNullable] on the result of of the given function [f].
  ///
  /// ```dart
  /// expect(
  ///   Option.of(123).flatMapNullable((_) => null),
  ///   Option.none(),
  /// );
  ///
  /// expect(
  ///   Option.of(123).flatMapNullable((_) => 456),
  ///   Option.of(456),
  /// );
  /// ```
  Option<B> flatMapNullable<B>(B? Function(A _) f) =>
      flatMap((_) => Option.fromNullable(f(_)));

  /// Return a new [Option] that calls [Option.tryCatch] with the given function [f].
  ///
  /// ```dart
  /// expect(
  ///   Option.of(123).flatMapThrowable((_) => throw Exception()),
  ///   Option.none(),
  /// );
  ///
  /// expect(
  ///   Option.of(123).flatMapThrowable((_) => 456),
  ///   Option.of(456),
  /// );
  /// ```
  Option<B> flatMapThrowable<B>(B Function(A _) f) =>
      flatMap((_) => Option.tryCatch(() => f(_)));
}
