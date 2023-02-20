import 'dart:async';

import 'package:elemental/elemental.dart';
import 'package:elemental/src/future_or.dart';
import 'package:fpdart/fpdart.dart' as fpdart;

class NoEnv {
  const NoEnv();
}

/// Represents an operation that cant fail, with no requirements
typedef IO<A> = ZIO<NoEnv, Never, A>;

/// Represents a IO with a [Scope]
typedef SIO<A> = ZIO<Scope, Never, A>;

/// Represents an operation that cant fail, with [R] requirements
typedef RIO<R, A> = ZIO<R, Never, A>;

/// Represents an operation that can fail, with no requirements
typedef EIO<E, A> = ZIO<NoEnv, E, A>;

/// Represents an operation that represent an optional value
typedef OptionIO<R, A> = ZIO<NoEnv, None<Never>, A>;

/// Represents an operation that represent an optional value
typedef OptionRIO<R, A> = ZIO<R, None<Never>, A>;

/// Represents a [ZIO] with a [Scope]
typedef SZIO<E, A> = ZIO<Scope, E, A>;

// Do notation helpers
typedef _DoAdapter<R, E> = FutureOr<A> Function<A>(ZIO<R, E, A> zio);

_DoAdapter<R, E> _doAdapter<R, E>(R env) =>
    <A>(zio) => zio._run(env).flatMap((ea) => ea.match(
          (e) => Future.error(Left<E, A>(e)),
          identity,
        ));

typedef DoFunction<R, E, A> = FutureOr<A> Function(
  // ignore: library_private_types_in_public_api
  _DoAdapter<R, E> $,
  R env,
);

/// Represents an operation that can fail with requirements
class ZIO<R, E, A> {
  ZIO.from(this._run);

  final FutureOr<Either<E, A>> Function(R env) _run;

  // Constructors

  factory ZIO(A Function() f) => ZIO.from((_) => Either.right(f()));

  factory ZIO.syncEnv(A Function(R env) f) =>
      ZIO.from((env) => Either.right(f(env)));

  factory ZIO.succeed(A a) => ZIO.fromEither(Either.right(a));

  factory ZIO.fail(E e) => ZIO.fromEither(Either.left(e));

  static ZIO<R, E, IList<A>> collect<R, E, A>(Iterable<ZIO<R, E, A>> zios) =>
      ZIO.traverseIterable<R, E, ZIO<R, E, A>, A>(
        zios,
        identity,
      );

  static ZIO<R, E, IList<A>> collectPar<R, E, A>(Iterable<ZIO<R, E, A>> zios) =>
      ZIO.traverseIterablePar<R, E, ZIO<R, E, A>, A>(
        zios,
        identity,
      );

  // ignore: non_constant_identifier_names
  factory ZIO.Do(DoFunction<R, E, A> f) => ZIO.from((env) => fromThrowable(
        () => f(_doAdapter(env), env),
        onSuccess: Either.right,
        onError: (e, s) {
          if (e is Left) {
            return e as Left<E, A>;
          }
          throw e;
        },
      ));

  static ZIO<R, E, A> Function<A>(DoFunction<R, E, A> f) makeDo<R, E>() =>
      <A>(f) => ZIO.Do(f);

  static ZIO<R, E, R> env<R, E>() => ZIO.from((env) => Either.right(env));

  factory ZIO.fromEither(Either<E, A> ea) => ZIO.from((_) => ea);

  static EIO<None<Never>, A> fromOption<A>(Option<A> oa) =>
      ZIO.fromEither(oa.match(
        () => Either.left(None()),
        Either.right,
      ));

  factory ZIO.fromOptionOrFail(
    Option<A> oa,
    E Function() onNone,
  ) =>
      ZIO.fromEither(oa.match(
        () => Either.left(onNone()),
        Either.right,
      ));

  factory ZIO.sleep(Duration duration) =>
      ZIO.unsafeFuture(() => Future.delayed(duration));

  factory ZIO.microtask(A Function() f) =>
      ZIO.unsafeFuture(() => Future.microtask(f));

  static ZIO<R, E, IList<B>> traverseIterable<R, E, A, B>(
    Iterable<A> iterable,
    ZIO<R, E, B> Function(A a) f,
  ) =>
      iterable.map((a) => f(a)).fold(
            ZIO.succeed(IList<B>()),
            (acc, zio) => acc.zipWith(zio, (a, B b) => a.add(b)),
          );

  static ZIO<R, E, IList<B>> traverseIterablePar<R, E, A, B>(
    Iterable<A> iterable,
    ZIO<R, E, B> Function(A a) f,
  ) =>
      ZIO.from(
        (env) {
          final results =
              iterable.map((a) => f(a)._run(env)).toList(growable: false);
          final hasFuture = results.any((eb) => eb is Future);

          if (!hasFuture) {
            return Either.sequenceList(
              results.cast<Either<E, B>>().toList(growable: false),
            ).map((a) => a.toIList());
          }

          return Future.wait(results.map((eb) => Future.value(eb))).then(
            (eithers) => Either.sequenceList(eithers).map((a) => a.toIList()),
          );
        },
      );

  factory ZIO.tryCatch(
    FutureOr<A> Function() f,
    E Function(dynamic error, StackTrace stackTrace) onError,
  ) =>
      ZIO.from(
        (_) => fromThrowable(
          f,
          onSuccess: Either.right,
          onError: (error, stack) => Either.left(onError(error, stack)),
        ),
      );

  factory ZIO.tryCatchEnv(
    FutureOr<A> Function(R env) f,
    E Function(dynamic error, StackTrace stackTrace) onError,
  ) =>
      ZIO.from(
        (env) => fromThrowable(
          () => f(env),
          onSuccess: Either.right,
          onError: (error, stack) => Either.left(onError(error, stack)),
        ),
      );

  static IO<Unit> unit() => ZIO.succeed(fpdart.unit);

  /// Creates a ZIO from a [Future].
  ///
  /// **This can be unsafe** because it will throw an error if the future fails.
  factory ZIO.unsafeFuture(
    FutureOr<A> Function() f,
  ) =>
      ZIO.from((_) => f().flatMap(Either.right));

  ZIO<R, E, B> as<B>(B b) => map((_) => b);

  ZIO<R, E, Unit> get asUnit => as(fpdart.unit);

  ZIO<R, E2, A> catchError<E2>(
    ZIO<R, E2, A> Function(E e) f,
  ) =>
      ZIO.from(
        (env) => this._run(env).flatMap((ea) => ea.match(
              (e) => f(e)._run(env),
              (a) => Either.right(a),
            )),
      );

  ZIO<R, E, A> delay(Duration duration) =>
      ZIO<R, E, A>.sleep(duration).zipRight(this);

  ZIO<R, E, A> filterOrFail(
    bool Function(A a) predicate,
    E Function(A a) onFalse,
  ) =>
      flatMapEither((a) => Either.fromPredicate(a, predicate, onFalse));

  ZIO<R, E, B> flatMap<B>(
    ZIO<R, E, B> Function(A a) f,
  ) =>
      ZIO.from(
        (env) => this._run(env).flatMap((ea) => ea.match(
              (e) => Either.left(e),
              (a) => f(a)._run(env),
            )),
      );

  ZIO<R, E, B> flatMapEither<B>(
    Either<E, B> Function(A a) f,
  ) =>
      ZIO.from((env) => this._run(env).flatMap((ea) => ea.flatMap(f)));

  ZIO<R, E, B> flatMapNullableOrFail<B>(
    B? Function(A a) f,
    E Function(A a) onNull,
  ) =>
      flatMapEither((a) => Either.fromNullable(f(a), () => onNull(a)));

  ZIO<R, E, B> flatMapOptionOrFail<B>(
    Option<B> Function(A a) f,
    E Function(A a) onNone,
  ) =>
      flatMapEither((a) => Either.fromOption(f(a), () => onNone(a)));

  RIO<R, A> getOrElse(
    A Function(E e) orElse,
  ) =>
      matchSync(orElse, identity);

  RIO<R, A?> get getOrNull => matchSync((e) => null, identity);

  RIO<R, Unit> get ignore => matchSync((e) => fpdart.unit, (a) => fpdart.unit);

  // TODO: Refactor so logger is a dependency
  RIO<R, Unit> get ignoreLogged => match(
        (e) => ZIO(() {
          print(e);
          return fpdart.unit;
        }),
        (a) => ZIO.succeed(fpdart.unit),
      );

  ZIO<R, E, B> map<B>(
    B Function(A a) f,
  ) =>
      ZIO.from((env) => this._run(env).flatMap((ea) => ea.map(f)));

  ZIO<R, E2, A> mapError<E2>(
    E2 Function(E e) f,
  ) =>
      ZIO.from((env) => this._run(env).flatMap((ea) => ea.mapLeft(f)));

  ZIO<R, E2, B> match<E2, B>(
    ZIO<R, E2, B> Function(E e) onError,
    ZIO<R, E2, B> Function(A a) onSuccess,
  ) =>
      ZIO.from(
        (env) => this._run(env).flatMap((ea) => ea.match(
              (e) => onError(e)._run(env),
              (a) => onSuccess(a)._run(env),
            )),
      );

  RIO<R, B> matchSync<B>(
    B Function(E e) onError,
    B Function(A a) onSuccess,
  ) =>
      ZIO.from(
        (env) => this._run(env).flatMap((ea) => ea.match(
              (e) => Either.right(onError(e)),
              (a) => Either.right(onSuccess(a)),
            )),
      );

  IO<ZIO<R, E, A>> get memoize => IO(() {
        final deferred = Deferred<Either<E, A>>();
        var executed = false;

        return ZIO.from((env) {
          if (executed) {
            return deferred.await
                .lift<R, E>()
                .flatMapEither(identity)
                ._run(env);
          }

          executed = true;
          return tapEither((ea) => deferred.complete(ea).lift())._run(env);
        });
      });

  ZIO<R, E, A> get microtask =>
      ZIO.from((env) => Future.microtask(() => _run(env)));

  EIO<E, A> provide(R env) {
    final zio = env is ScopeMixin && !env.scopeClosable
        ? zipLeftDefect(env.closeScope.lift())
        : this;
    return ZIO.from((_) => zio._run(env));
  }

  ZIO<R, E, A> tap<X>(
    ZIO<R, E, X> Function(A a) f,
  ) =>
      ZIO.from(
        (env) => _run(env).flatMap((ea) => ea.match(
              (e) => Either.left(e),
              (a) => f(a)._run(env).flatMap((ex) => ex.map((x) => a)),
            )),
      );

  ZIO<R, E, A> tapEither<X>(
    ZIO<R, E, X> Function(Either<E, A> ea) f,
  ) =>
      ZIO.from(
        (env) => _run(env).flatMap((ea) => f(ea)._run(env).flatMap((ex) => ea)),
      );

  ZIO<R, E, Tuple2<A, B>> zip<B>(ZIO<R, E, B> zio) =>
      zipWith(zio, (a, B b) => tuple2(a, b));

  ZIO<R, E, Tuple2<A, B>> zipPar<B>(ZIO<R, E, B> zio) =>
      zipParWith(zio, (a, B b) => tuple2(a, b));

  ZIO<R, E, A> zipParLeft<B>(ZIO<R, E, B> zio) =>
      zipParWith(zio, (a, B b) => a);

  ZIO<R, E, B> zipParRight<B>(ZIO<R, E, B> zio) =>
      zipParWith(zio, (a, B b) => b);

  ZIO<R, E, C> zipParWith<B, C>(
    ZIO<R, E, B> zio,
    C Function(A a, B b) resolve,
  ) =>
      ZIO.collectPar([this, zio]).map((a) => resolve(a[0] as A, a[1] as B));

  ZIO<R, E, A> zipLeft<X>(ZIO<R, E, X> zio) => tap((a) => zio);

  ZIO<R, E, A> zipLeftDefect<X>(ZIO<R, E, X> zio) => ZIO.from(
        (env) => fromThrowable<Either<E, A>, FutureOr<Either<E, A>>>(
          () => _run(env),
          onSuccess: (ea) => zio._run(env).flatMap((ex) => ea),
          onError: (e, s) =>
              zio._run(env).flatMap((ex) => Error.throwWithStackTrace(e, s)),
        ).flatMap(identity),
      );

  ZIO<R, E, B> zipRight<B>(ZIO<R, E, B> zio) => flatMap((a) => zio);

  ZIO<R, E, C> zipWith<B, C>(ZIO<R, E, B> zio, C Function(A, B) resolve) =>
      flatMap((a) => zio.map((b) => resolve(a, b)));
}

extension ZIORunExt<E, A> on EIO<E, A> {
  FutureOr<Either<E, A>> run() => _run(NoEnv());

  Future<A> runFuture() => Future.value(run()).then((ea) => ea.match(
        (e) => throw e as Object,
        identity,
      ));

  Future<Either<E, A>> runFutureEither() => Future.value(run());

  FutureOr<A> runFutureOr() => run().flatMap((ea) => ea.match(
        (e) => throw e as Object,
        identity,
      ));

  FutureOr<A> call() => runFutureOr();

  A runSync() => runSyncEither().match(
        (e) => throw e as Object,
        identity,
      );

  Either<E, A> runSyncEither() {
    final result = run();
    if (result is Future) {
      throw result;
    }
    return result;
  }
}

extension IOLiftExt<A> on IO<A> {
  ZIO<R, E, A> lift<R, E>() => ZIO.from((_) => _run(NoEnv()));
}

extension EIOLiftExt<E extends Object?, A> on EIO<E, A> {
  ZIO<R, E, A> lift<R>() => ZIO.from((_) => _run(NoEnv()));
}

extension RIOLiftExt<R extends Object, A> on RIO<R, A> {
  ZIO<R, E, A> lift<E>() => ZIO.from((env) => _run(env));
}

extension ZIOFinalizerExt<R extends ScopeMixin, E, A> on ZIO<R, E, A> {
  ZIO<R, E, A> acquireRelease(
    IO<Unit> Function(A a) release,
  ) =>
      tap((a) => addFinalizer(release(a)));

  ZIO<R, E, Unit> addFinalizer(
    IO<Unit> release,
  ) =>
      ZIO.env<R, E>().flatMap((env) => env.addScopeFinalizer(release).lift());
}

extension ZIOFinalizerNoEnvExt<E, A> on EIO<E, A> {
  ZIO<R, E, A> ask<R>() => ZIO.from((R env) => _run(NoEnv()));

  ZIO<Scope, E, A> acquireRelease(
    IO<Unit> Function(A a) release,
  ) =>
      ask<Scope>().tap((a) => addFinalizer(release(a)));

  ZIO<Scope, E, Unit> addFinalizer(
    IO<Unit> release,
  ) =>
      ZIO
          .env<Scope, E>()
          .flatMap((env) => env.addScopeFinalizer(release).lift());
}

extension ZIOScopeExt<E, A> on ZIO<Scope, E, A> {
  EIO<E, A> get scoped => provide(Scope());
}

extension ZIONoneExt<R, A> on OptionRIO<R, A> {
  ZIO<R, None<Never>, A> filter(
    bool Function(A a) predicate,
  ) =>
      filterOrFail(predicate, (a) => None());

  ZIO<R, None<Never>, B> flatMapNullable<B>(
    B? Function(A a) f,
  ) =>
      flatMapNullableOrFail(f, (a) => None());

  ZIO<R, None<Never>, B> flatMapOption<B>(
    Option<B> Function(A a) f,
  ) =>
      flatMapOptionOrFail(f, (a) => None());

  RIO<R, Option<A>> get option => matchSync(
        (a) => Option.none(),
        Option.of,
      );
}
