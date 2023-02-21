import 'dart:async';

import 'package:elemental/elemental.dart';
import 'package:elemental/src/future_or.dart';
import 'package:fpdart/fpdart.dart' as fpdart;

part 'zio/deferred.dart';
part 'zio/layer.dart';
part 'zio/logger.dart';
part 'zio/ref.dart';
part 'zio/runtime.dart';
part 'zio/scope.dart';

class NoEnv {
  const NoEnv();
}

/// Represents an operation that cant fail, with no requirements
typedef IO<A> = ZIO<NoEnv, Never, A>;

/// Represents an operation that cant fail, with [R] requirements
typedef RIO<R, A> = ZIO<R, Never, A>;

/// Represents an operation that can fail, with no requirements
typedef EIO<E, A> = ZIO<NoEnv, E, A>;

/// Represents an operation that represent an optional value
typedef IOOption<A> = ZIO<NoEnv, None<Never>, A>;

/// Represents an operation that represent an optional value
typedef RIOOption<R, A> = ZIO<R, None<Never>, A>;

// Do notation helpers
typedef _DoAdapter<R, E> = FutureOr<A> Function<A>(ZIO<R, E, A> zio);

_DoAdapter<R, E> _doAdapter<R, E>(R env, AtomRegistry r) =>
    <A>(zio) => zio._run(env, r).flatMapFOr((ea) => ea.match(
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

  static final defaultRegistry = AtomRegistry();

  final FutureOr<Either<E, A>> Function(R env, AtomRegistry r) _run;

  // Constructors

  factory ZIO(A Function() f) => ZIO.from((_, r) => Either.right(f()));
  static IO<A> sync<A>(A Function() f) => ZIO.from((_, r) => Either.right(f()));

  static RIO<R, A> syncEnv<R, A>(A Function(R env) f) =>
      ZIO.from((env, r) => Either.right(f(env)));
  factory ZIO.syncEnvLift(A Function(R env) f) => syncEnv(f);

  static IO<A> succeed<A>(A a) => ZIO.fromEither(Either.right(a));
  factory ZIO.succeedLift(A a) => succeed(a).lift();

  static EIO<E, Never> fail<E>(E e) => ZIO.fromEither(Either.left(e));
  factory ZIO.failLift(E e) => fail(e).lift();

  static ZIO<R, E, IList<A>> collect<R, E, A>(Iterable<ZIO<R, E, A>> zios) =>
      ZIO.traverseIterable<R, E, ZIO<R, E, A>, A>(
        zios,
        identity,
      );

  static ZIO<R, E, Unit> collectDiscard<R, E, A>(Iterable<ZIO<R, E, A>> zios) =>
      collect(zios).asUnit;

  static ZIO<R, E, IList<A>> collectPar<R, E, A>(Iterable<ZIO<R, E, A>> zios) =>
      ZIO.traverseIterablePar<R, E, ZIO<R, E, A>, A>(
        zios,
        identity,
      );

  static ZIO<R, E, Unit> collectParDiscard<R, E, A>(
    Iterable<ZIO<R, E, A>> zios,
  ) =>
      collectPar(zios).asUnit;

  // ignore: non_constant_identifier_names
  factory ZIO.Do(DoFunction<R, E, A> f) => ZIO.from((env, r) => fromThrowable(
        () => f(_doAdapter(env, r), env),
        onSuccess: Either.right,
        onError: (e, s) {
          if (e is Left) {
            return e as Left<E, A>;
          }
          throw e;
        },
      ));

  static RIO<R, R> env<R>() => ZIO.from((env, r) => Either.right(env));
  static ZIO<R, E, R> envLift<R, E>() => env<R>().lift();

  static RIO<R, A> envWith<R, A>(A Function(R env) f) => ZIO.env<R>().map(f);
  factory ZIO.envWithLift(A Function(R env) f) => envWith(f).lift();

  factory ZIO.envWithZIO(ZIO<R, E, A> Function(R env) f) => ZIO.from(
        (env, r) => f(env)._run(env, r),
      );

  static EIO<E, A> fromEither<E, A>(Either<E, A> ea) => ZIO.from((_, r) => ea);
  factory ZIO.fromEitherLift(Either<E, A> ea) => ZIO.from((_, r) => ea);

  static EIO<None<Never>, A> fromOption<A>(Option<A> oa) =>
      ZIO.fromEither(oa.match(
        () => Either.left(None()),
        Either.right,
      ));
  static ZIO<R, None<Never>, A> fromOptionLift<R, A>(Option<A> oa) =>
      fromOption(oa).lift();

  static EIO<E, A> fromOptionOrFail<E, A>(
    Option<A> oa,
    E Function() onNone,
  ) =>
      ZIO.fromEither(oa.match(
        () => Either.left(onNone()),
        Either.right,
      ));
  factory ZIO.fromOptionOrFailLift(Option<A> oa, E Function() onNone) =>
      fromOptionOrFail(oa, onNone).lift();

  static final IO<AtomRegistry> registry = ZIO.from((_, r) => Either.right(r));

  static IO<A> service<A>(Atom<A> atom) =>
      ZIO.from((_, r) => Either.right(r.get(atom)));
  static ZIO<R, E, A> serviceLift<R, E, A>(Atom<A> atom) =>
      service(atom).lift();

  static EIO<E, A> layer<E, A>(Layer<E, A> layer) =>
      ZIO.from((env, r) => r.get(layer._stateAtom).match(
            () => layer.getOrBuild._run(env, r),
            Either.right,
          ));
  static ZIO<R, E, A> layerLift<R, E, A>(Layer<E, A> ea) => layer(ea).lift();

  static IO<Unit> log(LogLevel level, String message) =>
      layer(loggerLayer).flatMap((log) => log.log(level, message));
  static ZIO<R, E, Unit> logLift<R, E>(LogLevel level, String message) =>
      log(level, message).lift();

  static IO<Unit> logDebug(String message) => log(LogLevel.debug, message);
  static ZIO<R, E, Unit> logDebugLift<R, E>(String message) =>
      logDebug(message).lift();

  static IO<Unit> logInfo(String message) => log(LogLevel.info, message);
  static ZIO<R, E, Unit> logInfoLift<R, E>(String message) =>
      logInfo(message).lift();

  static IO<Unit> logWarn(String message) => log(LogLevel.warn, message);
  static ZIO<R, E, Unit> logWarnLift<R, E>(String message) =>
      logWarn(message).lift();

  static IO<Unit> logError(String message) => log(LogLevel.error, message);
  static ZIO<R, E, Unit> logErrorLift<R, E>(String message) =>
      logError(message).lift();

  static IO<Unit> sleep(Duration duration) =>
      ZIO.unsafeFuture(() => Future.delayed(duration, () => fpdart.unit));
  static ZIO<R, E, Unit> sleepLift<R, E>(Duration duration) =>
      sleep(duration).lift();

  static ZIO<R, E, IList<B>> traverseIterable<R, E, A, B>(
    Iterable<A> iterable,
    ZIO<R, E, B> Function(A _) f,
  ) =>
      iterable.map((a) => f(a)).fold(
            ZIO.succeed(IList<B>()).lift(),
            (acc, zio) => acc.zipWith(zio, (a, B b) => a.add(b)),
          );

  static ZIO<R, E, IList<B>> traverseIterablePar<R, E, A, B>(
    Iterable<A> iterable,
    ZIO<R, E, B> Function(A _) f,
  ) =>
      ZIO.from(
        (env, r) {
          final results =
              iterable.map((a) => f(a)._run(env, r)).toList(growable: false);
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

  static EIO<E, A> tryCatch<E, A>(
    FutureOr<A> Function() f,
    E Function(dynamic error, StackTrace stackTrace) onError,
  ) =>
      ZIO.from(
        (env, r) => fromThrowable(
          f,
          onSuccess: Either.right,
          onError: (error, stack) => Either.left(onError(error, stack)),
        ),
      );
  factory ZIO.tryCatchLift(
    FutureOr<A> Function() f,
    E Function(dynamic error, StackTrace stackTrace) onError,
  ) =>
      tryCatch(f, onError).lift();
  static IOOption<A> tryCatchOption<A>(
    FutureOr<A> Function() f,
  ) =>
      tryCatch(f, (error, stack) => None());

  factory ZIO.tryCatchEnv(
    FutureOr<A> Function(R env) f,
    E Function(dynamic error, StackTrace stackTrace) onError,
  ) =>
      ZIO.from(
        (env, r) => fromThrowable(
          () => f(env),
          onSuccess: Either.right,
          onError: (error, stack) => Either.left(onError(error, stack)),
        ),
      );

  static final unit = ZIO.succeed(fpdart.unit);
  static ZIO<R, E, Unit> unitLift<R, E>() => unit.lift();

  /// Creates a ZIO from a [Future].
  ///
  /// **This can be unsafe** because it will throw an error if the future fails.
  static IO<A> unsafeFuture<A>(FutureOr<A> Function() f) =>
      ZIO.from((_, r) => f().flatMapFOr(Either.right));

  /// Creates a ZIO from a [Future].
  ///
  /// **This can be unsafe** because it will throw an error if the future fails.
  factory ZIO.unsafeFutureLift(FutureOr<A> Function() f) =>
      unsafeFuture(f).lift();

  ZIO<R, E, A> always(ZIO<R, E, A> zio) => ZIO.from(
        (env, r) => fromThrowable<Either<E, A>, FutureOr<Either<E, A>>>(
          () => _run(env, r),
          onSuccess: (ea) => zio._run(env, r),
          onError: (e, s) => zio._run(env, r),
        ).flatMapFOr(identity),
      );

  ZIO<R, E, A> alwaysIgnore<X>(ZIO<R, E, X> zio) => ZIO.from(
        (env, r) => fromThrowable<Either<E, A>, FutureOr<Either<E, A>>>(
          () => _run(env, r),
          onSuccess: (ea) => zio._run(env, r).flatMapFOr((ex) => ea),
          onError: (e, s) => zio
              ._run(env, r)
              .flatMapFOr((ex) => Error.throwWithStackTrace(e, s)),
        ).flatMapFOr(identity),
      );

  ZIO<R, E, B> as<B>(B b) => map((_) => b);

  ZIO<R, E, Unit> get asUnit => as(fpdart.unit);

  ZIO<R, E, A> catchDefect(
    ZIO<R, E, A> Function(dynamic error, StackTrace stack) f,
  ) =>
      ZIO.from(
        (env, r) => fromThrowable<Either<E, A>, FutureOr<Either<E, A>>>(
          () => _run(env, r),
          onSuccess: identity,
          onError: (e, s) => f(e, s)._run(env, r),
        ).flatMapFOr(identity),
      );

  ZIO<R, E2, A> catchError<E2>(
    ZIO<R, E2, A> Function(E _) f,
  ) =>
      ZIO.from(
        (env, r) => this._run(env, r).flatMapFOr((ea) => ea.match(
              (e) => f(e)._run(env, r),
              (a) => Either.right(a),
            )),
      );

  ZIO<R, E, A> delay(Duration duration) =>
      ZIO.sleep(duration).lift<R, E>().zipRight(this);

  ZIO<R, E, A> filterOrFail(
    bool Function(A _) predicate,
    E Function(A _) onFalse,
  ) =>
      flatMapEither((a) => Either.fromPredicate(a, predicate, onFalse));

  ZIO<R, E, B> flatMap<B>(
    ZIO<R, E, B> Function(A _) f,
  ) =>
      ZIO.from(
        (env, r) => _run(env, r).flatMapFOr(
          (ea) => ea.match(
            (e) => Either.left(e),
            (a) => f(a)._run(env, r),
          ),
        ),
      );

  ZIO<R, E, Tuple2<A, B>> flatMap2<B>(
    ZIO<R, E, B> Function(A _) f,
  ) =>
      flatMap((a) => f(a).map((b) => tuple2(a, b)));

  ZIO<R, E, B> flatMapEither<B>(
    Either<E, B> Function(A _) f,
  ) =>
      ZIO.from((env, r) => this._run(env, r).flatMapFOr((ea) => ea.flatMap(f)));

  ZIO<R, E, B> flatMapEnv<B>(
    ZIO<R, E, B> Function(A _, R env) f,
  ) =>
      ZIO.from(
        (env, r) => this._run(env, r).flatMapFOr(
              (ea) => ea.match(
                (e) => Either.left(e),
                (a) => f(a, env)._run(env, r),
              ),
            ),
      );

  ZIO<R, E, B> flatMapRegistry<B>(
    ZIO<R, E, B> Function(A _, AtomRegistry r) f,
  ) =>
      ZIO.from(
        (env, r) => this._run(env, r).flatMapFOr(
              (ea) => ea.match(
                (e) => Either.left(e),
                (a) => f(a, r)._run(env, r),
              ),
            ),
      );

  ZIO<R, E, B> flatMapNullableOrFail<B>(
    B? Function(A _) f,
    E Function(A _) onNull,
  ) =>
      flatMapEither((a) => Either.fromNullable(f(a), () => onNull(a)));

  ZIO<R, E, B> flatMapOptionOrFail<B>(
    Option<B> Function(A _) f,
    E Function(A _) onNone,
  ) =>
      flatMapEither((a) => Either.fromOption(f(a), () => onNone(a)));

  ZIO<R, E, B> flatMapThrowable<B>(
    FutureOr<B> Function(A _) f,
    E Function(dynamic error, StackTrace stack) onThrow,
  ) =>
      flatMap((a) => ZIO.tryCatch(() => f(a), onThrow).lift());

  ZIO<R, E, B> flatMapThrowableEnv<B>(
    FutureOr<B> Function(A _, R env) f,
    E Function(dynamic error, StackTrace stack) onThrow,
  ) =>
      flatMapEnv((a, env) => ZIO.tryCatch(() => f(a, env), onThrow).lift());

  RIO<R, A> getOrElse(
    A Function(E _) orElse,
  ) =>
      matchSync(orElse, identity);

  RIO<R, A?> get getOrNull => matchSync((e) => null, identity);

  RIO<R, Unit> get ignore => matchSync((e) => fpdart.unit, (a) => fpdart.unit);

  RIO<R, Unit> get ignoreLogged => match(
        (e) => ZIO
            .layer(loggerLayer)
            .flatMap((logger) => logger.warn("$e"))
            .lift(),
        (a) => ZIO.succeed(fpdart.unit).lift(),
      );

  ZIO<R, E, B> map<B>(
    B Function(A _) f,
  ) =>
      ZIO.from((env, r) => this._run(env, r).flatMapFOr((ea) => ea.map(f)));

  ZIO<R, E2, A> mapError<E2>(
    E2 Function(E _) f,
  ) =>
      ZIO.from((env, r) => this._run(env, r).flatMapFOr((ea) => ea.mapLeft(f)));

  ZIO<R, E2, B> match<E2, B>(
    ZIO<R, E2, B> Function(E _) onError,
    ZIO<R, E2, B> Function(A _) onSuccess,
  ) =>
      ZIO.from(
        (env, r) => this._run(env, r).flatMapFOr((ea) => ea.match(
              (e) => onError(e)._run(env, r),
              (a) => onSuccess(a)._run(env, r),
            )),
      );

  RIO<R, B> matchSync<B>(
    B Function(E _) onError,
    B Function(A _) onSuccess,
  ) =>
      ZIO.from(
        (env, r) => this._run(env, r).flatMapFOr((ea) => ea.match(
              (e) => Either.right(onError(e)),
              (a) => Either.right(onSuccess(a)),
            )),
      );

  IO<ZIO<R, E, A>> get memoize => IO(() {
        final deferred = Deferred<Either<E, A>>();
        var executed = false;

        return ZIO.from((env, r) {
          if (executed) {
            return deferred.await
                .lift<R, E>()
                .flatMapEither(identity)
                ._run(env, r);
          }

          executed = true;
          return tapEither((ea) => deferred.complete(ea).lift())._run(env, r);
        });
      });

  ZIO<R, E, A> get microtask =>
      ZIO.from((env, r) => Future.microtask(() => _run(env, r)));

  EIO<E, A> provide(R env) {
    final zio = env is ScopeMixin && !env.scopeClosable
        ? alwaysIgnore(env.closeScope.lift())
        : this;
    return ZIO.from((_, r) => zio._run(env, r));
  }

  ZIO<R, E, A> withRuntime(Runtime runtime) =>
      ZIO.from((env, _) => _run(env, runtime.registry));

  ZIO<R, E, A> tap<X>(
    ZIO<R, E, X> Function(A _) f,
  ) =>
      flatMap((a) => f(a).as(a));

  ZIO<R, E, A> tapEnv<X>(
    ZIO<R, E, X> Function(A _, R env) f,
  ) =>
      flatMapEnv((a, env) => f(a, env).as(a));

  ZIO<R, E, A> tapRegistry<X>(
    ZIO<R, E, X> Function(A _, AtomRegistry r) f,
  ) =>
      flatMapRegistry((a, r) => f(a, r).as(a));

  ZIO<R, E, A> tapError<X>(
    ZIO<R, E, X> Function(E _) f,
  ) =>
      catchError((e) => f(e).zipRight(ZIO.fail(e).lift()));

  ZIO<R, E, A> tapEither<X>(
    ZIO<R, E, X> Function(Either<E, A> _) f,
  ) =>
      ZIO.from(
        (env, r) => _run(env, r).flatMapFOr(
          (ea) => f(ea)._run(env, r).flatMapFOr((ex) => ea),
        ),
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

  ZIO<R, E, B> zipRight<B>(ZIO<R, E, B> zio) => flatMap((a) => zio);

  ZIO<R, E, C> zipWith<B, C>(ZIO<R, E, B> zio, C Function(A a, B b) resolve) =>
      flatMap((a) => zio.map((b) => resolve(a, b)));
}

extension ZIORunExt<E, A> on EIO<E, A> {
  FutureOr<Either<E, A>> run([AtomRegistry? registry]) =>
      (registry?.zioRuntime ?? Runtime.defaultRuntime).run(this);

  Future<A> runFuture([AtomRegistry? registry]) =>
      (registry?.zioRuntime ?? Runtime.defaultRuntime).runFuture(this);

  Future<Either<E, A>> runFutureEither([AtomRegistry? registry]) =>
      (registry?.zioRuntime ?? Runtime.defaultRuntime).runFutureEither(this);

  FutureOr<A> runFutureOr([AtomRegistry? registry]) =>
      (registry?.zioRuntime ?? Runtime.defaultRuntime).runFutureOr(this);

  Either<E, A> runSyncEither([AtomRegistry? registry]) =>
      (registry?.zioRuntime ?? Runtime.defaultRuntime).runSyncEither(this);
}

extension IORunSyncExt<A> on IO<A> {
  A runSync([AtomRegistry? registry]) =>
      (registry?.zioRuntime ?? Runtime.defaultRuntime).runSync(this);
}

extension IOLiftExt<A> on IO<A> {
  ZIO<R, E, A> lift<R, E>() => ask<R>().mapError((_) => _ as E);
  EIO<E, A> liftError<E>() => lift<NoEnv, E>();
}

extension EIOLiftExt<E extends Object?, A> on EIO<E, A> {
  ZIO<R, E, A> lift<R>() => ask<R>();
  EIO<E2, A> liftError<E2>() => mapError((e) => e as E2);
}

extension RIOLiftExt<R extends Object?, A> on RIO<R, A> {
  ZIO<R, E, A> lift<E>() => mapError((_) => _ as E);
  ZIO<R, E, A> liftError<E>() => lift<E>();
}

extension ZIOFinalizerExt<R extends ScopeMixin, E, A> on ZIO<R, E, A> {
  ZIO<R, E, A> acquireRelease(
    IO<Unit> Function(A _) release,
  ) =>
      tap((a) => addFinalizer(release(a)));

  ZIO<R, E, Unit> addFinalizer(
    IO<Unit> release,
  ) =>
      flatMapEnv((_, env) => env.addScopeFinalizer(release).lift());
}

extension ZIOFinalizerNoEnvExt<E, A> on EIO<E, A> {
  ZIO<R, E, A> ask<R>() => ZIO.from((R env, r) => _run(NoEnv(), r));

  ZIO<Scope, E, A> acquireRelease(
    IO<Unit> Function(A _) release,
  ) =>
      ask<Scope>().tap((a) => addFinalizer(release(a)));

  ZIO<Scope, E, Unit> addFinalizer(
    IO<Unit> release,
  ) =>
      ask<Scope>()
          .flatMapEnv((_, env) => env.addScopeFinalizer(release).lift());
}

extension ZIOScopeExt<E, A> on ZIO<Scope, E, A> {
  EIO<E, A> get scoped => provide(Scope());
}

extension ZIONoneExt<R, A> on RIOOption<R, A> {
  ZIO<R, None<Never>, A> filter(
    bool Function(A _) predicate,
  ) =>
      filterOrFail(predicate, (a) => None());

  ZIO<R, None<Never>, B> flatMapNullable<B>(
    B? Function(A _) f,
  ) =>
      flatMapNullableOrFail(f, (a) => None());

  ZIO<R, None<Never>, B> flatMapOption<B>(
    Option<B> Function(A _) f,
  ) =>
      flatMapOptionOrFail(f, (a) => None());

  RIO<R, Option<A>> get option => matchSync(
        (a) => Option.none(),
        Option.of,
      );
}

extension ZIOIterableExt<R, E, A> on Iterable<ZIO<R, E, A>> {
  ZIO<R, E, IList<A>> collect() => ZIO.collect(this);
  ZIO<R, E, Unit> collectDiscard() => ZIO.collectDiscard(this);
  ZIO<R, E, IList<A>> collectPar() => ZIO.collectPar(this);
  ZIO<R, E, Unit> collectParDiscard() => ZIO.collectParDiscard(this);
}

extension ZIOEitherExt<E, A> on Either<E, A> {
  ZIO<NoEnv, E, A> toZIO() => ZIO.fromEither(this);
}

extension ZIOOptionExt<A> on Option<A> {
  ZIO<NoEnv, None<Never>, A> toZIO() => ZIO.fromOption(this);
  ZIO<NoEnv, E, A> toZIOOrFail<E>(E Function() onNone) =>
      ZIO.fromOptionOrFail(this, onNone);
}
