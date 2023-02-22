import 'dart:async';

import 'package:elemental/elemental.dart';
import 'package:elemental/src/future_or.dart';
import 'package:fpdart/fpdart.dart' as fpdart;

part 'zio/deferred.dart';
part 'zio/exit.dart';
part 'zio/layer.dart';
part 'zio/logger.dart';
part 'zio/ref.dart';
part 'zio/runtime.dart';
part 'zio/schedule.dart';
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

_DoAdapter<R, E> _doAdapter<R, E>(
  R env,
  AtomRegistry r,
  Deferred<Unit> cancel,
) =>
    <A>(zio) => zio._run(env, r, cancel).flatMapFOr(
          (ea) => ea.match(
            (e) => Future.error(Left<Cause<E>, A>(e)),
            identity,
          ),
          interruptionSignal: cancel,
        );

typedef DoFunction<R, E, A> = FutureOr<A> Function(
  // ignore: library_private_types_in_public_api
  _DoAdapter<R, E> $,
  R env,
);

typedef ZIORunFn<R, E, A> = FutureOr<Exit<E, A>> Function(
  R env,
  AtomRegistry r,
  Deferred<Unit> c,
);

// For the const unit
FutureOr<Exit<E, Unit>> _kZioUnit<R, E>(
  R env,
  AtomRegistry r,
  Deferred<Unit> c,
) =>
    Exit.right(unit);

/// Represents an operation that can fail with requirements
class ZIO<R, E, A> {
  const ZIO.from(this._unsafeRun);

  final FutureOr<Exit<E, A>> Function(
    R env,
    AtomRegistry r,
    Deferred<Unit> c,
  ) _unsafeRun;

  FutureOr<Exit<E, A>> _run(
    R env,
    AtomRegistry r,
    Deferred<Unit> c,
  ) {
    try {
      return _unsafeRun(env, r, c);
    } catch (err, stack) {
      return Exit.left(Defect(err, stack));
    }
  }

  // Constructors

  factory ZIO(A Function() f) => ZIO.from((_, r, c) => Either.right(f()));

  factory ZIO.succeed(A a) => ZIO.fromEither(Either.right(a));

  factory ZIO.fail(E e) => ZIO.fromEither(Either.left(e));

  factory ZIO.failCause(Cause<E> cause) => ZIO.fromExit(Either.left(cause));

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
  factory ZIO.Do(DoFunction<R, E, A> f) =>
      ZIO.from((env, r, c) => fromThrowable(
            () => f(_doAdapter(env, r, c), env),
            onError: (err, stack) {
              if (err is Left<Cause<E>, A>) {
                return err.value;
              }

              return Defect(err, stack);
            },
            interruptionSignal: c,
          ));

  static RIO<R, R> env<R>() => ZIO.from((env, r, c) => Either.right(env));

  factory ZIO.envWith(A Function(R env) f) =>
      ZIO.from((env, r, c) => Either.right(f(env)));

  factory ZIO.envWithZIO(ZIO<R, E, A> Function(R env) f) =>
      ZIO.from((env, r, c) => f(env)._run(env, r, c));

  factory ZIO.fromEither(Either<E, A> ea) => ZIO.fromExit(ea.toExit());

  factory ZIO.fromExit(Exit<E, A> ea) => ZIO.from((_, r, c) => ea);

  static EIO<None<Never>, A> fromOption<A>(Option<A> oa) =>
      ZIO.fromEither(oa.match(
        () => Either.left(None()),
        Either.right,
      ));

  factory ZIO.fromOptionOrFail(
    Option<A> oa,
    E Function() onNone,
  ) =>
      ZIO.syncEither(() => oa.toEither(() => onNone()));

  static final IO<AtomRegistry> registry =
      ZIO.from((_, r, c) => Either.right(r));

  factory ZIO.service(Atom<A> atom) =>
      ZIO.from((_, r, c) => Either.right(r.get(atom)));

  factory ZIO.layer(Layer<E, A> layer) =>
      ZIO.from((env, r, c) => r.get(layer._stateAtom).match(
            () => layer.getOrBuild._run(NoEnv(), r, c),
            Either.right,
          ));

  static ZIO<R, E, Unit> log<R, E>(
    LogLevel level,
    String message, {
    Map<String, dynamic>? annotations,
  }) =>
      ZIO<R, E, Logger>.layer(loggerLayer).flatMap(
        (log) => log
            .log(level, message, annotations: annotations ?? const {})
            .lift(),
      );
  static IO<Unit> logIO(LogLevel level, String message) => log(level, message);

  static ZIO<R, E, Unit> logDebug<R, E>(
    String message, {
    Map<String, dynamic>? annotations,
  }) =>
      log(LogLevel.debug, message);

  static IO<Unit> logDebugIO(
    String message, {
    Map<String, dynamic>? annotations,
  }) =>
      logDebug(message, annotations: annotations);

  static ZIO<R, E, Unit> logInfo<R, E>(
    String message, {
    Map<String, dynamic>? annotations,
  }) =>
      log(LogLevel.info, message);

  static IO<Unit> logInfoIO(
    String message, {
    Map<String, dynamic>? annotations,
  }) =>
      logInfo(message, annotations: annotations);

  static ZIO<R, E, Unit> logWarn<R, E>(
    String message, {
    Map<String, dynamic>? annotations,
  }) =>
      log(LogLevel.warn, message);

  static IO<Unit> logWarnIO(
    String message, {
    Map<String, dynamic>? annotations,
  }) =>
      logWarn(message, annotations: annotations);

  static ZIO<R, E, Unit> logError<R, E>(
    String message, {
    Map<String, dynamic>? annotations,
  }) =>
      log(LogLevel.error, message);

  static IO<Unit> logErrorIO(
    String message, {
    Map<String, dynamic>? annotations,
  }) =>
      logError(message, annotations: annotations);

  static ZIO<R, E, Unit> sleep<R, E>(Duration duration) =>
      ZIO.unsafeFuture(() => Future.delayed(duration, () => fpdart.unit));

  static IO<Unit> sleepIO(Duration duration) => sleep(duration);

  factory ZIO.syncEither(Either<E, A> Function() f) =>
      ZIO.from((_, r, c) => f().toExit());

  factory ZIO.syncExit(Exit<E, A> Function() f) => ZIO.from((_, r, c) => f());

  static ZIO<R, E, IList<B>> traverseIterable<R, E, A, B>(
    Iterable<A> iterable,
    ZIO<R, E, B> Function(A _) f,
  ) =>
      ZIO.from(
        (env, r, c) => iterable
            .map((a) => f(a))
            .fold<ZIO<R, E, IList<B>>>(
              ZIO.succeed(IList()),
              (acc, zio) => acc.zipWith(zio, (a, B b) => a.add(b)),
            )
            ._run(env, r, c),
      );

  static ZIO<R, E, IList<B>> traverseIterablePar<R, E, A, B>(
    Iterable<A> iterable,
    ZIO<R, E, B> Function(A _) f,
  ) =>
      ZIO.from(
        (env, r, c) {
          final results =
              iterable.map((a) => f(a)._run(env, r, c)).toList(growable: false);
          final hasFuture = results.any((eb) => eb is Future);

          if (!hasFuture) {
            return Either.sequenceList(
              results.cast<Either<E, B>>().toList(growable: false),
            ).map((a) => a.toIList()).toExit();
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
        (env, r, c) => fromThrowable(
          f,
          interruptionSignal: c,
          onError: (e, s) => Failure(onError(e, s)),
        ),
      );

  factory ZIO.tryCatchEnv(
    FutureOr<A> Function(R env) f,
    E Function(dynamic error, StackTrace stackTrace) onError,
  ) =>
      ZIO.from(
        (env, r, c) => fromThrowable(
          () => f(env),
          interruptionSignal: c,
          onError: (e, s) => Failure(onError(e, s)),
        ),
      );

  static IOOption<A> tryCatchOption<A>(
    FutureOr<A> Function() f,
  ) =>
      ZIO.tryCatch(f, (_, s) => None());

  static const unitIO = IO.from(_kZioUnit);
  static ZIO<R, E, Unit> unit<R, E>() => ZIO.from(_kZioUnit);

  /// Creates a ZIO from a [Future].
  ///
  /// **This can be unsafe** because it will throw an error if the future fails.
  factory ZIO.unsafeFuture(FutureOr<A> Function() f) => ZIO
      .from((_, r, c) => f().flatMapFOr(Either.right, interruptionSignal: c));

  ZIO<R, E, A> always(ZIO<R, E, A> zio) =>
      ZIO.from((env, r, c) => _run(env, r, c).flatMapFOrNoI(
            (exit) => zio._run(env, r, Deferred()),
          ));

  ZIO<R, E, A> alwaysIgnore<X>(ZIO<R, E, X> zio) => ZIO.from(
        (env, r, c) => _run(env, r, c).flatMapFOrNoI(
          (exit) =>
              zio._run(env, r, Deferred()).flatMapFOrNoI((_) => _.call(exit)),
        ),
      );

  ZIO<R, E, B> as<B>(B b) => map((_) => b);

  ZIO<R, E, Unit> get asUnit => as(fpdart.unit);

  ZIO<R, E2, A> _mapCauseFOr<E2>(
    FutureOr<Exit<E2, A>> Function(
      R env,
      AtomRegistry r,
      Deferred<Unit> c,
      Cause<E> _,
    )
        f,
  ) =>
      ZIO.from(
        (env, r, c) => _run(env, r, c).flatMapFOr(
          (exit) => exit.match((cause) => f(env, r, c, cause), Exit.right),
          interruptionSignal: c,
        ),
      );

  ZIO<R, E2, A> catchCause<E2>(
    ZIO<R, E2, A> Function(Cause<E> _) f,
  ) =>
      _mapCauseFOr((env, r, c, _) => f(_)._run(env, r, c));

  ZIO<R, E2, A> catchDefect<E2>(
    ZIO<R, E2, A> Function(Defect<E> _) f,
  ) =>
      _mapCauseFOr(
        (env, r, c, _) =>
            _ is Defect<E> ? f(_)._run(env, r, c) : Either.left(_.lift()),
      );

  ZIO<R, E2, A> catchError<E2>(
    ZIO<R, E2, A> Function(E _) f,
  ) =>
      _mapCauseFOr(
        (env, r, c, _) => _ is Failure<E>
            ? f(_.error)._run(env, r, c)
            : Either.left(_.lift()),
      );

  ZIO<R, E, A> delay(Duration duration) =>
      ZIO.sleep<R, E>(duration).zipRight(this);

  RIO<R, Either<E, A>> get either =>
      ZIO.from((env, r, c) => _run(env, r, c).flatMapFOrNoI(
            (exit) => exit.matchExit(
              (_) => Either.right(Either.left(_)),
              (_) => Either.right(Either.right(_)),
            ),
          ));

  ZIO<R, E, A> filterOrFail(
    bool Function(A _) predicate,
    E Function(A _) onFalse,
  ) =>
      flatMapEither((a) => Either.fromPredicate(a, predicate, onFalse));

  ZIO<R, E, B> flatMap<B>(
    ZIO<R, E, B> Function(A _) f,
  ) =>
      ZIO.from(
        (env, r, c) => _run(env, r, c).flatMapFOr(
          (ea) => ea.match(
            (e) => Either.left(e),
            (a) => f(a)._run(env, r, c),
          ),
          interruptionSignal: c,
        ),
      );

  ZIO<R, E, Tuple2<A, B>> flatMap2<B>(
    ZIO<R, E, B> Function(A _) f,
  ) =>
      flatMap((a) => f(a).map((b) => tuple2(a, b)));

  ZIO<R, E, B> flatMapEither<B>(
    Either<E, B> Function(A _) f,
  ) =>
      ZIO.from(
        (env, r, c) => _run(env, r, c).flatMapFOrNoI(
          (ea) => ea.flatMapExitEither(f),
        ),
      );

  ZIO<R, E, B> flatMapEnv<B>(
    ZIO<R, E, B> Function(A _, R env) f,
  ) =>
      ZIO.from(
        (env, r, c) => _run(env, r, c).flatMapFOr(
          (ea) => ea.match(
            (e) => Either.left(e),
            (a) => f(a, env)._run(env, r, c),
          ),
          interruptionSignal: c,
        ),
      );

  ZIO<R, E, B> flatMapRegistry<B>(
    ZIO<R, E, B> Function(A _, AtomRegistry r) f,
  ) =>
      ZIO.from(
        (env, r, c) => _run(env, r, c).flatMapFOr(
          (ea) => ea.match(
            (e) => Either.left(e),
            (a) => f(a, r)._run(env, r, c),
          ),
          interruptionSignal: c,
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
      flatMap((a) => ZIO.tryCatch(() => f(a), onThrow));

  ZIO<R, E, B> flatMapThrowableEnv<B>(
    FutureOr<B> Function(A _, R env) f,
    E Function(dynamic error, StackTrace stack) onThrow,
  ) =>
      flatMapEnv((a, env) => ZIO.tryCatch(() => f(a, env), onThrow));

  ZIO<R, E, Never> get forever {
    ZIO<R, E, Never> loop() => flatMap((_) => loop());
    return loop();
  }

  RIO<R, A> getOrElse(
    A Function(E _) orElse,
  ) =>
      matchSync(orElse, identity);

  RIO<R, A?> get getOrNull => matchSync((e) => null, identity);

  RIO<R, Unit> get ignore => matchSync((e) => fpdart.unit, (a) => fpdart.unit);

  RIO<R, Unit> get ignoreLogged =>
      tapError((_) => logWarn(_.toString())).ignore;

  ZIO<R, E, B> map<B>(
    B Function(A _) f,
  ) =>
      ZIO.from((env, r, c) => _run(env, r, c).flatMapFOr(
            (ea) => ea.map(f),
            interruptionSignal: c,
          ));

  ZIO<R, E2, A> mapError<E2>(
    E2 Function(E _) f,
  ) =>
      ZIO.from((env, r, c) => _run(env, r, c).flatMapFOrNoI(
            (ea) => ea.mapFailure(f),
          ));

  ZIO<R, E2, B> match<E2, B>(
    ZIO<R, E2, B> Function(E _) onError,
    ZIO<R, E2, B> Function(A _) onSuccess,
  ) =>
      ZIO.from(
        (env, r, c) => _run(env, r, c).flatMapFOr(
          (ea) => ea._matchExitFOr(
            (e) => onError(e)._run(env, r, c),
            (a) => onSuccess(a)._run(env, r, c),
          ),
          interruptionSignal: c,
        ),
      );

  RIO<R, B> matchSync<B>(
    B Function(E _) onError,
    B Function(A _) onSuccess,
  ) =>
      ZIO.from(
        (env, r, c) => _run(env, r, c).flatMapFOr(
          (ea) => ea.matchExit(
            (e) => Either.right(onError(e)),
            (a) => Either.right(onSuccess(a)),
          ),
          interruptionSignal: c,
        ),
      );

  IO<ZIO<R, E, A>> get memoize => IO(() {
        final deferred = Deferred<Either<E, A>>();
        var executed = false;

        return ZIO.from((env, r, c) {
          if (executed) {
            return deferred.await
                .lift<R, E>()
                .flatMapEither(identity)
                ._run(env, r, c);
          }

          executed = true;
          return tapEither((ea) => deferred.complete(ea).lift())
              ._run(env, r, c);
        });
      });

  ZIO<R, E, A> get microtask =>
      ZIO.from((env, r, c) => Future.microtask(() => _run(env, r, c)));

  EIO<E, A> provide(R env) {
    final zio = env is ScopeMixin && !env.scopeClosable
        ? alwaysIgnore(env.closeScope.lift())
        : this;
    return ZIO.from((_, r, c) => zio._run(env, r, c));
  }

  ZIO<R, E, A> repeat<O>(Schedule<R, E, A, O> schedule) =>
      schedule.driver.lift<R, E>().flatMap((driver) {
        ZIO<R, E, A> loop() => flatMap((a) => driver.next(a).match(
              (e) => e.match(
                () => ZIO.succeed(a),
                (e) => ZIO.fail(e),
              ),
              (_) => loop(),
            ));

        return loop();
      });

  ZIO<R, E, A> repeatN(int n) =>
      flatMap((_) => n > 0 ? repeatN(n - 1) : ZIO.succeed(_));

  ZIO<R, E, A> repeatWhile(
    bool Function(A _) predicate,
  ) =>
      flatMap((_) => predicate(_) ? repeatWhile(predicate) : ZIO.succeed(_));

  ZIO<R, E, A> retry<O>(Schedule<R, E, E, O> schedule) =>
      schedule.driver.lift<R, E>().flatMap((driver) {
        ZIO<R, E, A> loop() => catchError((error) => driver.next(error).match(
              (e) => e.match(
                () => ZIO.fail(error),
                (e) => ZIO.fail(e),
              ),
              (_) => loop(),
            ));

        return loop();
      });

  ZIO<R, E, A> retryN(int n) =>
      catchError((_) => n > 0 ? retryN(n - 1) : ZIO.fail(_));

  ZIO<R, E, A> retryWhile(
    bool Function(E _) predicate,
  ) =>
      catchError((_) => predicate(_) ? retryWhile(predicate) : ZIO.fail(_));

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
      catchError((e) => f(e).zipRight(ZIO.fail(e)));

  ZIO<R, E, A> tapErrorCause<X>(
    ZIO<R, E, X> Function(Cause<E> _) f,
  ) =>
      catchCause((e) => f(e).zipRight(ZIO.failCause(e)));

  ZIO<R, E, A> tapEither<X>(
    ZIO<R, E, X> Function(Either<E, A> _) f,
  ) =>
      ZIO.from(
        (env, r, c) => _run(env, r, c).flatMapFOr(
          (exit) => exit._matchExitFOr(
            (e) => f(Either.left(e))._run(env, r, c).flatMapFOr(
                  (fExit) => fExit.flatMapExit((_) => exit),
                  interruptionSignal: c,
                ),
            Either.right,
          ),
          interruptionSignal: c,
        ),
      );

  ZIO<R, E, A> tapExit<X>(
    ZIO<R, E, X> Function(Exit<E, A> _) f,
  ) =>
      ZIO.from(
        (env, r, c) => _run(env, r, c).flatMapFOr(
          (exit) => f(exit)._run(env, r, c).flatMapFOr(
                (fExit) => fExit.flatMapExit((_) => exit),
                interruptionSignal: c,
              ),
          interruptionSignal: c,
        ),
      );

  ZIO<R, E, A> withRuntime(Runtime runtime) =>
      ZIO.from((env, r, c) => _run(env, runtime.registry, c));

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
  FutureOr<Exit<E, A>> run({
    AtomRegistry? registry,
    Deferred<Unit>? interruptionSignal,
  }) =>
      (registry?.zioRuntime ?? Runtime.defaultRuntime).run(
        this,
        interruptionSignal: interruptionSignal,
      );

  Future<A> runFutureOrThrow({
    AtomRegistry? registry,
    Deferred<Unit>? interruptionSignal,
  }) =>
      (registry?.zioRuntime ?? Runtime.defaultRuntime).runFutureOrThrow(
        this,
        interruptionSignal: interruptionSignal,
      );

  Future<Exit<E, A>> runFuture({
    AtomRegistry? registry,
    Deferred<Unit>? interruptionSignal,
  }) =>
      (registry?.zioRuntime ?? Runtime.defaultRuntime).runFuture(
        this,
        interruptionSignal: interruptionSignal,
      );

  FutureOr<A> runOrThrow({
    AtomRegistry? registry,
    Deferred<Unit>? interruptionSignal,
  }) =>
      (registry?.zioRuntime ?? Runtime.defaultRuntime).runOrThrow(
        this,
        interruptionSignal: interruptionSignal,
      );

  Exit<E, A> runSync({
    AtomRegistry? registry,
    Deferred<Unit>? interruptionSignal,
  }) =>
      (registry?.zioRuntime ?? Runtime.defaultRuntime).runSync(
        this,
        interruptionSignal: interruptionSignal,
      );

  A runSyncOrThrow([AtomRegistry? registry]) =>
      (registry?.zioRuntime ?? Runtime.defaultRuntime).runSyncOrThrow(this);
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
  ZIO<R, E, A> ask<R>() => ZIO.from((R env, r, c) => _run(NoEnv(), r, c));

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
