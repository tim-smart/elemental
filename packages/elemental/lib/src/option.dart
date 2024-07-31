import 'package:elemental/elemental.dart';

final class _OptionThrow {
  const _OptionThrow();
}

typedef DoAdapterOption = A Function<A>(Option<A>);
A _doAdapter<A>(Option<A> option) =>
    option.getOrElse(() => throw const _OptionThrow());

typedef DoFunctionOption<A> = A Function(DoAdapterOption $);

/// A type that can contain a value of type `T` in a [Some] or no value with [None].
///
/// Used to represent type-safe missing values. Instead of using `null`, you define the type
/// to be [Option]. In this way, you are required by the type system to handle the case in which
/// the value is missing.
/// ```dart
/// final Option<String> mStr = Option.of('name');
///
/// /// Using [Option] you are required to specify every possible case.
/// /// The type system helps you to find and define edge-cases and avoid errors.
/// mStr.match(
///   () => print('I have no string to print 🤷‍♀️'),
///   printString,
/// );
/// ```
sealed class Option<T> implements IZIO<NoEnv, None, T> {
  const Option();

  /// Initialize a **Do Notation** chain.
  // ignore: non_constant_identifier_names
  factory Option.Do(DoFunctionOption<T> f) {
    try {
      return Option.of(f(_doAdapter));
    } on _OptionThrow catch (_) {
      return const Option.none();
    }
  }

  /// Change the value of type `T` to a value of type `B` using function `f`.
  /// ```dart
  /// /// Change type `String` (`T`) to type `int` (`B`)
  /// final Option<String> mStr = Option.of('name');
  /// final Option<int> mInt = mStr.map((a) => a.length);
  /// ```
  /// 👇
  /// ```dart
  /// [🥚].map((🥚) => 👨‍🍳(🥚)) -> [🍳]
  /// [_].map((🥚) => 👨‍🍳(🥚)) -> [_]
  /// ```
  Option<B> map<B>(B Function(T t) f);

  /// Apply the function contained inside `a` to change the value of type `T` to
  /// a value of type `B`.
  ///
  /// If `a` is [None], return [None].
  /// ```dart
  /// final a = Option.of(10);
  /// final b = Option.of(20);
  ///
  /// /// `map` takes one parameter [int] and returns `sumToDouble`.
  /// /// We therefore have a function inside a [Option] that we want to
  /// /// apply to another value!
  /// final Option<double Function(int)> map = a.map(
  ///   (a) => (int b) => sumToDouble(a, b),
  /// );
  ///
  /// /// Using `ap`, we get the final `Option<double>` that we want 🚀
  /// final result = b.ap(map);
  /// ```
  Option<B> ap<B>(covariant Option<B Function(T t)> a) => a.match(
        () => Option<B>.none(),
        (f) => map(f),
      );

  /// Used to chain multiple functions that return a [Option].
  ///
  /// You can extract the value of every [Option] in the chain without
  /// handling all possible missing cases.
  /// If any of the functions in the chain returns [None], the result is [None].
  /// ```dart
  /// /// Using `flatMap`, you can forget that the value may be missing and just
  /// /// use it as if it was there.
  /// ///
  /// /// In case one of the values is actually missing, you will get a [None]
  /// /// at the end of the chain ⛓
  /// final a = Option.of('name');
  /// final Option<double> result = a.flatMap(
  ///   (s) => stringToInt(s).flatMap(
  ///     (i) => intToDouble(i),
  ///   ),
  /// );
  /// ```
  /// 👇
  /// ```dart
  /// [😀].flatMap(
  ///     (😀) => [👻(😀)]
  ///     ) -> [😱]
  ///
  /// [😀].flatMap(
  ///     (😀) => [👻(😀)]
  ///     ).flatMap(
  ///         (😱) => [👨‍⚕️(😱)]
  ///         ) -> [🤕]
  ///
  /// [😀].flatMap(
  ///     (😀) => [_]
  ///     ).flatMap(
  ///         (_) => [👨‍⚕️(_)]
  ///         ) -> [_]
  ///
  /// [_].flatMap(
  ///     (😀) => [👻(😀)]
  ///     ) -> [_]
  /// ```
  Option<B> flatMap<B>(covariant Option<B> Function(T t) f);

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
  Option<B> flatMapNullable<B>(B? Function(T t) f) =>
      flatMap((t) => Option.fromNullable(f(t)));

  /// Return a new [Option] that calls [Option.tryCatch] with the given function [f].
  ///
  /// ```dart
  /// expect(
  ///   Option.of(123).flatMapThrowable((_) => throw Exception()),
  ///   Option.of(123).flatMapThrowable((_) => 456),
  ///   Option.of(456),
  /// );
  /// ```
  Option<B> flatMapThrowable<B>(B Function(T t) f) =>
      flatMap((t) => Option.tryCatch(() => f(t)));

  /// Change the value of [Option] from type `T` to type `Z` based on the
  /// value of `Option<T>` using function `f`.
  Option<Z> extend<Z>(Z Function(Option<T> t) f);

  /// Wrap this [Option] inside another [Option].
  Option<Option<T>> duplicate() => extend(identity);

  /// If this [Option] is a [Some] and calling `f` returns `true`, then return this [Some].
  /// Otherwise return [None].
  Option<T> filter(bool Function(T t) f) =>
      flatMap((t) => f(t) ? this : const Option.none());

  /// If this [Option] is a [Some] and calling `f` returns [Some], then return this [Some].
  /// Otherwise return [None].
  Option<Z> filterMap<Z>(Option<Z> Function(T t) f);

  /// Return a record. If this [Option] is a [Some]:
  /// - if `f` applied to its value returns `true`, then the tuple contains this [Option] as second value
  /// - if `f` applied to its value returns `false`, then the tuple contains this [Option] as first value
  /// Otherwise the tuple contains both [None].
  (Option<T>, Option<T>) partition(bool Function(T t) f) =>
      (filter((a) => !f(a)), filter(f));

  /// Return a record that contains as first value a [Some] when `f` returns [Left],
  /// otherwise the [Some] will be the second value of the tuple.
  (Option<Z>, Option<Y>) partitionMap<Z, Y>(Either<Z, Y> Function(T t) f) =>
      Option.separate(map(f));

  /// If this [Option] is a [Some], then return the result of calling `then`.
  /// Otherwise return [None].
  /// ```dart
  /// [🍌].andThen(() => [🍎]) -> [🍎]
  /// [_].andThen(() => [🍎]) -> [_]
  /// ```
  Option<B> andThen<B>(covariant Option<B> Function() then) =>
      flatMap((_) => then());

  /// Chain multiple [Option]s.
  Option<B> call<B>(covariant Option<B> chain) => flatMap((_) => chain);

  /// Change type of this [Option] based on its value of type `T` and the
  /// value of type `C` of another [Option].
  Option<D> map2<C, D>(covariant Option<C> mc, D Function(T t, C c) f) =>
      flatMap((a) => mc.map((c) => f(a, c)));

  /// Change type of this [Option] based on its value of type `T`, the
  /// value of type `C` of a second [Option], and the value of type `D`
  /// of a third [Option].
  Option<E> map3<C, D, E>(
    covariant Option<C> mc,
    covariant Option<D> md,
    E Function(T t, C c, D d) f,
  ) =>
      flatMap((a) => mc.flatMap((c) => md.map((d) => f(a, c, d))));

  /// {@template elemental_option_match}
  /// Execute `onSome` when value is [Some], otherwise execute `onNone`.
  /// {@endtemplate}
  /// ```dart
  /// [🍌].match(() => 🍎, (🍌) => 🍌 * 2) -> 🍌🍌
  /// [_].match(() => 🍎, (🍌) => 🍌 * 2) -> 🍎
  /// ```
  B match<B>(B Function() onNone, B Function(T t) onSome);

  /// Return `true` when value is [Some].
  bool isSome();

  /// Return `true` when value is [None].
  bool isNone();

  /// Return value of type `T` when this [Option] is a [Some], `null` otherwise.
  T? toNullable();

  /// Build an [Either] from [Option].
  ///
  /// Return [Right] when [Option] is [Some], otherwise [Left] containing
  /// the result of calling `onLeft`.
  Either<L, T> toEither<L>(L Function() onLeft) => match(
        () => Left(onLeft()),
        Right.new,
      );

  /// {@template elemental_traverse_list_option}
  /// Map each element in the list to an [Option] using the function `f`,
  /// and collect the result in an `Option<List<B>>`.
  ///
  /// If any mapped element of the list is [None], then the final result
  /// will be [None].
  /// {@endtemplate}
  ///
  /// Same as `Option.traverseList` but passing `index` in the map function.
  static Option<List<B>> traverseListWithIndex<A, B>(
    List<A> list,
    Option<B> Function(A a, int i) f,
  ) {
    final resultList = <B>[];
    for (var i = 0; i < list.length; i++) {
      final o = f(list[i], i);
      final r = o.match<B?>(() => null, identity);
      if (r == null) return const Option.none();
      resultList.add(r);
    }

    return Option.of(resultList);
  }

  /// {@macro elemental_traverse_list_option}
  ///
  /// Same as `Option.traverseListWithIndex` but without `index` in the map function.
  static Option<List<B>> traverseList<A, B>(
    List<A> list,
    Option<B> Function(A a) f,
  ) =>
      traverseListWithIndex<A, B>(list, (a, _) => f(a));

  /// {@template elemental_sequence_list_option}
  /// Convert a `List<Option<A>>` to a single `Option<List<A>>`.
  ///
  /// If any of the [Option] in the [List] is [None], then the result is [None].
  /// {@endtemplate}
  static Option<List<A>> sequenceList<A>(
    List<Option<A>> list,
  ) =>
      traverseList(list, identity);

  /// Build a [Option] from a [Either] by returning [Some] when `either` is [Right],
  /// [None] otherwise.
  static Option<R> fromEither<L, R>(Either<L, R> either) =>
      either.match((_) => const Option.none(), (r) => Some(r));

  /// {@template elemental_safe_cast_option}
  /// Safely cast a value to type `T`.
  ///
  /// If `value` is not of type `T`, then return a [None].
  /// {@endtemplate}
  ///
  /// Less strict version of `Option.safeCastStrict`, since `safeCast`
  /// assumes the value to be `dynamic`.
  ///
  /// **Note**: Make sure to specify the type of [Option] (`Option<T>.safeCast`
  /// instead of `Option.safeCast`), otherwise this will always return [Some]!
  factory Option.safeCast(dynamic value) =>
      Option.safeCastStrict<T, dynamic>(value);

  /// {@macro elemental_safe_cast_option}
  ///
  /// More strict version of `Option.safeCast`, in which also the **input value
  /// type** must be specified (while in `Option.safeCast` the type is `dynamic`).
  static Option<T> safeCastStrict<T, V>(V value) =>
      value is T ? Option<T>.of(value) : Option<T>.none();

  /// Return [Some] of `value` when `predicate` applied to `value` returns `true`,
  /// [None] otherwise.
  factory Option.fromPredicate(T value, bool Function(T t) predicate) =>
      // ignore: prefer_const_constructors
      predicate(value) ? Some(value) : Option.none();

  /// Return [Some] of type `B` by calling `f` with `value` when `predicate` applied to `value` is `true`,
  /// `None` otherwise.
  /// ```dart
  /// /// If the value of `str` is not empty, then return a [Some] containing
  /// /// the `length` of `str`, otherwise [None].
  /// Option.fromPredicateMap<String, int>(
  ///   str,
  ///   (str) => str.isNotEmpty,
  ///   (str) => str.length,
  /// );
  /// ```
  static Option<B> fromPredicateMap<A, B>(
          A value, bool Function(A a) predicate, B Function(A a) f) =>
      // ignore: prefer_const_constructors
      predicate(value) ? Some(f(value)) : Option.none();

  /// Return a [None].
  const factory Option.none() = None;

  /// Return a `Some(a)`.
  const factory Option.of(T t) = Some<T>;

  /// Flat a [Option] contained inside another [Option] to be a single [Option].
  factory Option.flatten(Option<Option<T>> m) => m.flatMap(identity);

  /// Return [None] if `a` is `null`, [Some] otherwise.
  // ignore: prefer_const_constructors
  factory Option.fromNullable(T? t) => t == null ? Option.none() : Some(t);

  /// Try to run `f` and return `Some(a)` when no error are thrown, otherwise return `None`.
  factory Option.tryCatch(T Function() f) {
    try {
      return Some(f());
    } catch (_) {
      return const Option.none();
    }
  }

  /// Return a record of [Option] from a `Option<Either<A, B>>`.
  ///
  /// The value on the left of the [Either] will be the first value of the tuple,
  /// while the right value of the [Either] will be the second of the tuple.
  static (Option<A>, Option<B>) separate<A, B>(Option<Either<A, B>> m) =>
      m.match(
        () => (const Option.none(), const Option.none()),
        (either) => (either.getLeft(), either.getRight()),
      );

  /// Converts from Json.
  ///
  /// Json serialization support for `json_serializable` with `@JsonSerializable`.
  factory Option.fromJson(
    dynamic json,
    T Function(dynamic json) fromJsonT,
  ) =>
      json != null
          ? Option.tryCatch(() => fromJsonT(json))
          : const Option.none();

  /// Converts to Json.
  ///
  /// Json serialization support for `json_serializable` with `@JsonSerializable`.
  Object? toJson(Object? Function(T) toJsonT);
}

class Some<T> extends Option<T> {
  final T _value;
  const Some(this._value);

  /// Extract value of type `T` inside the [Some].
  T get value => _value;

  @override
  Option<D> map2<C, D>(covariant Option<C> mc, D Function(T t, C c) f) =>
      flatMap((a) => mc.map((c) => f(a, c)));

  @override
  Option<E> map3<C, D, E>(covariant Option<C> mc, covariant Option<D> md,
          E Function(T t, C c, D d) f) =>
      flatMap((a) => mc.flatMap((c) => md.map((d) => f(a, c, d))));

  @override
  Option<B> map<B>(B Function(T t) f) => Some(f(_value));

  @override
  Option<B> flatMap<B>(covariant Option<B> Function(T t) f) => f(_value);

  @override
  B match<B>(B Function() onNone, B Function(T t) onSome) => onSome(_value);

  @override
  Option<Z> extend<Z>(Z Function(Option<T> t) f) => Some(f(this));

  @override
  bool isSome() => true;

  @override
  bool isNone() => false;

  @override
  // ignore: prefer_const_constructors
  Option<T> filter(bool Function(T t) f) => f(_value) ? this : Option.none();

  @override
  Option<Z> filterMap<Z>(Option<Z> Function(T t) f) => f(_value).match(
        () => const Option.none(),
        Some.new,
      );

  @override
  T toNullable() => _value;

  @override
  Either<L, T> toEither<L>(L Function() onLeft) => Right(_value);

  @override
  bool operator ==(Object other) => (other is Some) && other._value == _value;

  @override
  int get hashCode => _value.hashCode;

  @override
  String toString() => 'Some($_value)';

  @override
  Object? toJson(Object? Function(T p1) toJsonT) => toJsonT(_value);

  @override
  ZIO<NoEnv, None, T> get asZIO => ZIO.succeed(_value);
}

class None extends Option<Never> {
  const None();

  @override
  Option<D> map2<C, D>(covariant Option<C> mc, D Function(Never t, C c) f) =>
      this;

  @override
  Option<E> map3<C, D, E>(
    covariant Option<C> mc,
    covariant Option<D> md,
    E Function(Never t, C c, D d) f,
  ) =>
      this;

  @override
  Option<B> map<B>(B Function(Never t) f) => this;

  @override
  Option<B> flatMap<B>(covariant Option<B> Function(Never t) f) => this;

  @override
  B match<B>(B Function() onNone, B Function(Never t) onSome) => onNone();

  @override
  Option<Z> extend<Z>(Z Function(Option<Never> t) f) => const Option.none();

  @override
  bool isSome() => false;

  @override
  bool isNone() => true;

  @override
  Option<Z> filterMap<Z>(Option<Z> Function(Never t) f) => const Option.none();

  @override
  bool operator ==(Object other) => other is None;

  @override
  Null toNullable() => null;

  @override
  int get hashCode => 0;

  @override
  String toString() => 'None';

  @override
  Object? toJson(Object? Function(Never p1) toJsonT) => null;

  @override
  ZIO<NoEnv, None, Never> get asZIO => ZIO.fail(const None());
}

extension OptionExtension<T> on Option<T> {
  /// Return the current [Option] if it is a [Some], otherwise return the result of `orElse`.
  ///
  /// Used to provide an **alt**ernative [Option] in case the current one is [None].
  /// ```dart
  /// [🍌].alt(() => [🍎]) -> [🍌]
  /// [_].alt(() => [🍎]) -> [🍎]
  /// ```
  Option<T> alt(Option<T> Function() orElse) =>
      this is Some<T> ? this : orElse();

  /// If this [Option] is a [Some] then return the value inside the [Option].
  /// Otherwise return the result of `orElse`.
  /// ```dart
  /// [🍌].getOrElse(() => 🍎) -> 🍌
  /// [_].getOrElse(() => 🍎) -> 🍎
  ///
  ///  👆 same as 👇
  ///
  /// [🍌].match(() => 🍎, (🍌) => 🍌)
  /// ```
  T getOrElse(T Function() orElse) => match(orElse, identity);
}
