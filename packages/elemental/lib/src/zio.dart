import 'dart:async';
import 'dart:collection';

import 'package:elemental/elemental.dart';
import 'package:elemental/src/future_or.dart';
import 'package:fpdart/fpdart.dart' as fpdart;
import 'package:meta/meta.dart';

part 'zio/context.dart';
part 'zio/deferred.dart';
part 'zio/exit.dart';
part 'zio/layer.dart';
part 'zio/logger.dart';
part 'zio/ref.dart';
part 'zio/runner.dart';
part 'zio/runtime.dart';
part 'zio/schedule.dart';
part 'zio/scope.dart';

class NoEnv {
  const NoEnv();

  @override
  String toString() => 'NoEnv()';
}

class NoValue {
  const NoValue();

  @override
  String toString() => 'NoValue()';
}

/// Represents an operation that cant fail, with no requirements
typedef IO<A> = ZIO<NoEnv, Never, A>;

/// Represents an operation that cant fail, with [R] requirements
typedef RIO<R, A> = ZIO<R, Never, A>;

/// Represents an operation that can fail, with no requirements
typedef EIO<E, A> = ZIO<NoEnv, E, A>;

/// Represents an operation that represent an optional value
typedef IOOption<A> = ZIO<NoEnv, NoValue, A>;

/// Represents an operation that represent an optional value
typedef RIOOption<R, A> = ZIO<R, NoValue, A>;

// Do notation helpers
typedef _DoAdapter<R, E> = FutureOr<A> Function<A>(ZIO<R, E, A> zio);

_DoAdapter<R, E> _doAdapter<R, E>(ZIOContext<R> ctx) =>
    <A>(zio) => zio._run(ctx).flatMapFOr(
          (ea) => ea.match(
            (e) => Future.error(Left<Cause<E>, A>(e)),
            identity,
          ),
          interruptionSignal: ctx.signal,
        );

typedef DoFunction<R, E, A> = FutureOr<A> Function(
  // ignore: library_private_types_in_public_api
  _DoAdapter<R, E> $,
  R env,
);

// For the const unit
FutureOr<Exit<E, Unit>> _kZioUnit<R, E>(ZIOContext<R> ctx) => Exit.right(unit);

/// Represents an operation that can fail with requirements
class ZIO<R, E, A> {
  const ZIO.from(this._unsafeRun);

  final FutureOr<Exit<E, A>> Function(ZIOContext<R> ctx) _unsafeRun;

  FutureOr<Exit<E, A>> _run(ZIOContext<R> ctx) {
    try {
      return _unsafeRun(ctx);
    } catch (err, stack) {
      return Exit.left(Defect(err, stack));
    }
  }

  // Constructors

  factory ZIO(A Function() f) => ZIO.from((ctx) => Either.right(f()));

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
  factory ZIO.Do(DoFunction<R, E, A> f) => ZIO.from((ctx) => fromThrowable(
        () => f(_doAdapter(ctx), ctx.env),
        onError: (err, stack) {
          if (err is Left<Cause<E>, A>) {
            return err.value;
          }

          return Defect(err, stack);
        },
        interruptionSignal: ctx.signal,
      ));

  static RIO<R, R> env<R>() => ZIO.from((ctx) => Either.right(ctx.env));

  factory ZIO.envWith(A Function(R env) f) =>
      ZIO.from((ctx) => Either.right(f(ctx.env)));

  factory ZIO.envWithZIO(ZIO<R, E, A> Function(R env) f) =>
      ZIO.from((ctx) => f(ctx.env)._run(ctx));

  factory ZIO.fromEither(Either<E, A> ea) => ZIO.fromExit(ea.toExit());

  factory ZIO.fromExit(Exit<E, A> ea) => ZIO.from((ctx) => ea);

  static IOOption<A> fromNullable<A>(A? a) =>
      ZIO.fromOption(Option.fromNullable(a));

  factory ZIO.fromNullableOrFail(A? a, E Function() onNull) =>
      ZIO.fromOptionOrFail(Option.fromNullable(a), onNull);

  static IOOption<A> fromOption<A>(Option<A> oa) => ZIO.fromEither(oa.match(
        () => Either.left(const NoValue()),
        Either.right,
      ));

  factory ZIO.fromOptionOrFail(
    Option<A> oa,
    E Function() onNone,
  ) =>
      ZIO.syncEither(() => oa.toEither(() => onNone()));

  factory ZIO.layer(Layer<E, A> layer) =>
      ZIO.from((ctx) => ctx.accessLayer<E, A>(layer)._run(ctx));

  static ZIO<R, E, Unit> log<R, E>(
    LogLevel level,
    String message, {
    Map<String, dynamic>? annotations,
  }) =>
      ZIO.from((ctx) => ctx
          .accessLayer<E, Logger>(loggerLayer)
          .flatMap(
            (log) => log.log(
              level,
              DateTime.now(),
              message,
              annotations: {
                ...annotations ?? {},
                ...ctx.unsafeGetAndClearAnnotations(loggerAnnotationsSymbol),
              },
            ),
          )
          ._run(ctx));

  static IO<Unit> logIO(LogLevel level, String message) => log(level, message);

  static ZIO<R, E, Unit> logDebug<R, E>(
    String message, {
    Map<String, dynamic>? annotations,
  }) =>
      log(LogLevel.debug, message, annotations: annotations);

  static IO<Unit> logDebugIO(
    String message, {
    Map<String, dynamic>? annotations,
  }) =>
      logDebug(message, annotations: annotations);

  static ZIO<R, E, Unit> logInfo<R, E>(
    String message, {
    Map<String, dynamic>? annotations,
  }) =>
      log(LogLevel.info, message, annotations: annotations);

  static IO<Unit> logInfoIO(
    String message, {
    Map<String, dynamic>? annotations,
  }) =>
      logInfo(message, annotations: annotations);

  static ZIO<R, E, Unit> logWarn<R, E>(
    String message, {
    Map<String, dynamic>? annotations,
  }) =>
      log(LogLevel.warn, message, annotations: annotations);

  static IO<Unit> logWarnIO(
    String message, {
    Map<String, dynamic>? annotations,
  }) =>
      logWarn(message, annotations: annotations);

  static ZIO<R, E, Unit> logError<R, E>(
    String message, {
    Map<String, dynamic>? annotations,
  }) =>
      log(LogLevel.error, message, annotations: annotations);

  static IO<Unit> logErrorIO(
    String message, {
    Map<String, dynamic>? annotations,
  }) =>
      logError(message, annotations: annotations);

  static ZIO<R, E, Runtime> runtime<R, E>() =>
      ZIO.from((ctx) => Either.right(ctx.runtime));

  static final IO<Runtime> runtimeIO = runtime();

  static ZIO<R, E, Unit> sleep<R, E>(Duration duration) =>
      ZIO.unsafeFuture(() => Future.delayed(duration, () => fpdart.unit));

  static IO<Unit> sleepIO(Duration duration) => sleep(duration);

  factory ZIO.syncEither(Either<E, A> Function() f) =>
      ZIO.from((ctx) => f().toExit());

  factory ZIO.syncExit(Exit<E, A> Function() f) => ZIO.from((ctx) => f());

  static ZIO<R, E, IList<B>> traverseIterable<R, E, A, B>(
    Iterable<A> iterable,
    ZIO<R, E, B> Function(A _) f,
  ) =>
      ZIO.from(
        (ctx) => iterable
            .map((a) => f(a))
            .fold<ZIO<R, E, IList<B>>>(
              ZIO.succeed(IList()),
              (acc, zio) => acc.zipWith(zio, (a, B b) => a.add(b)),
            )
            ._run(ctx),
      );

  static ZIO<R, E, IList<B>> traverseIterablePar<R, E, A, B>(
    Iterable<A> iterable,
    ZIO<R, E, B> Function(A _) f,
  ) =>
      ZIO.from(
        (ctx) {
          final results =
              iterable.map((a) => f(a)._run(ctx)).toList(growable: false);
          final hasFuture = results.any((eb) => eb is Future);

          if (!hasFuture) {
            return Either.sequenceList(
              results.cast<Exit<E, B>>().toList(growable: false),
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
        (ctx) => fromThrowable(
          f,
          interruptionSignal: ctx.signal,
          onError: (e, s) => Failure(onError(e, s)),
        ),
      );

  factory ZIO.tryCatchEnv(
    FutureOr<A> Function(R env) f,
    E Function(dynamic error, StackTrace stackTrace) onError,
  ) =>
      ZIO.from(
        (ctx) => fromThrowable(
          () => f(ctx.env),
          interruptionSignal: ctx.signal,
          onError: (e, s) => Failure(onError(e, s)),
        ),
      );

  static IOOption<A> tryCatchOption<A>(
    FutureOr<A> Function() f,
  ) =>
      ZIO.tryCatch(f, (_, s) => const NoValue());

  static const unitIO = IO.from(_kZioUnit);
  static ZIO<R, E, Unit> unit<R, E>() => ZIO.from(_kZioUnit);

  /// Creates a ZIO from a [Future].
  ///
  /// **This can be unsafe** because it will throw an error if the future fails.
  factory ZIO.unsafeFuture(FutureOr<A> Function() f) => ZIO.from(
      (ctx) => f().flatMapFOr(Either.right, interruptionSignal: ctx.signal));

  ZIO<R, E, A> always(ZIO<R, E, A> zio) =>
      ZIO.from((ctx) => _run(ctx).flatMapFOrNoI(
            (exit) => zio._run(ctx.withoutSignal),
          ));

  ZIO<R, E, A> alwaysIgnore<X>(ZIO<R, E, X> zio) => ZIO.from(
        (ctx) => _run(ctx).flatMapFOrNoI(
          (exit) =>
              zio._run(ctx.withoutSignal).flatMapFOrNoI((_) => _.call(exit)),
        ),
      );

  ZIO<R, E, A> annotate(Symbol key, String name, dynamic value) =>
      ZIO.from((ctx) {
        ctx.unsafeAnnotate(key, name, value);
        return _run(ctx);
      });

  /// Retrieves and clears the annotations for the provided key.
  ZIO<R, E, HashMap<String, dynamic>> annotations(Symbol key) =>
      ZIO.from((ctx) => Exit.right(ctx.unsafeGetAndClearAnnotations(key)));

  ZIO<R, E, A> annotateLog(String name, dynamic value) =>
      annotate(loggerAnnotationsSymbol, name, value);

  ZIO<R, E, B> as<B>(B b) => map((_) => b);

  ZIO<R, E, Unit> get asUnit => as(fpdart.unit);

  ZIO<R, E2, A> _mapCauseFOr<E2>(
    FutureOr<Exit<E2, A>> Function(
      ZIOContext<R>,
      Cause<E> _,
    )
        f,
  ) =>
      ZIO.from(
        (ctx) => _run(ctx).flatMapFOr(
          (exit) => exit.match((cause) => f(ctx, cause), Exit.right),
          interruptionSignal: ctx.signal,
        ),
      );

  ZIO<R, E2, A> catchCause<E2>(
    ZIO<R, E2, A> Function(Cause<E> _) f,
  ) =>
      _mapCauseFOr((ctx, _) => f(_)._run(ctx));

  ZIO<R, E2, A> catchDefect<E2>(
    ZIO<R, E2, A> Function(Defect<E> _) f,
  ) =>
      _mapCauseFOr(
        (ctx, _) => _ is Defect<E> ? f(_)._run(ctx) : Either.left(_.lift()),
      );

  ZIO<R, E2, A> catchError<E2>(
    ZIO<R, E2, A> Function(E _) f,
  ) =>
      _mapCauseFOr(
        (ctx, _) =>
            _ is Failure<E> ? f(_.error)._run(ctx) : Either.left(_.lift()),
      );

  ZIO<R, E, A> delay(Duration duration) =>
      ZIO.sleep<R, E>(duration).zipRight(this);

  RIO<R, Either<E, A>> get either => ZIO.from((ctx) => _run(ctx).flatMapFOrNoI(
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
        (ctx) => _run(ctx).flatMapFOr(
          (ea) => ea.match(
            (e) => Either.left(e),
            (a) => f(a)._run(ctx),
          ),
          interruptionSignal: ctx.signal,
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
        (ctx) => _run(ctx).flatMapFOrNoI(
          (ea) => ea.flatMapExitEither(f),
        ),
      );

  ZIO<R, E, B> flatMapEnv<B>(
    ZIO<R, E, B> Function(A _, R env) f,
  ) =>
      ZIO.from(
        (ctx) => _run(ctx).flatMapFOr(
          (ea) => ea.match(
            (e) => Either.left(e),
            (a) => f(a, ctx.env)._run(ctx),
          ),
          interruptionSignal: ctx.signal,
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
      ZIO.from((ctx) => _run(ctx).flatMapFOr(
            (ea) => ea.map(f),
            interruptionSignal: ctx.signal,
          ));

  ZIO<R, E2, A> mapError<E2>(
    E2 Function(E _) f,
  ) =>
      ZIO.from((ctx) => _run(ctx).flatMapFOrNoI(
            (ea) => ea.mapFailure(f),
          ));

  ZIO<R, E2, B> match<E2, B>(
    ZIO<R, E2, B> Function(E _) onError,
    ZIO<R, E2, B> Function(A _) onSuccess,
  ) =>
      ZIO.from(
        (ctx) => _run(ctx).flatMapFOr(
          (ea) => ea._matchExitFOr(
            (e) => onError(e)._run(ctx),
            (a) => onSuccess(a)._run(ctx),
          ),
          interruptionSignal: ctx.signal,
        ),
      );

  RIO<R, B> matchSync<B>(
    B Function(E _) onError,
    B Function(A _) onSuccess,
  ) =>
      ZIO.from(
        (ctx) => _run(ctx).flatMapFOr(
          (ea) => ea.matchExit(
            (e) => Either.right(onError(e)),
            (a) => Either.right(onSuccess(a)),
          ),
          interruptionSignal: ctx.signal,
        ),
      );

  IO<ZIO<R, E, A>> get memoize => IO(() {
        final deferred = Deferred<Exit<E, A>>();
        var executed = false;

        return ZIO<R, E, A>.from((ctx) {
          if (executed) {
            return deferred
                .await<R, E>()
                ._run(ctx)
                .flatMapFOrNoI((exit) => exit.flatMap(identity));
          }

          executed = true;
          return tapExit(deferred.complete)._run(ctx);
        });
      });

  ZIO<R, E, A> get microtask =>
      ZIO.from((ctx) => Future.microtask(() => _run(ctx)));

  RIO<R, A> get orDie => _mapCauseFOr((ctx, _) => _ is Failure<E>
      ? Exit.left(Defect(_, StackTrace.current))
      : Exit.left(_.lift()));

  EIO<E, A> provide(R env) {
    final zio = env is ScopeMixin && !env.scopeClosable
        ? alwaysIgnore(env.closeScope())
        : this;
    return ZIO.from((ctx) => zio._run(ctx.withEnv(env)));
  }

  ZIO<R, E, A> provideLayer(Layer<E, dynamic> layer) =>
      ZIO.from((ctx) => ctx.provideLayer(layer).zipRight(this)._run(ctx));

  ZIO<R, E, A> Function(S service) provideService<S>(Layer<dynamic, S> layer) =>
      (service) => ZIO.from(
            (ctx) => ctx
                .provideService<E, S>(layer, service)
                .zipRight(this)
                ._run(ctx),
          );

  ZIO<R, E, A> repeat<O>(Schedule<R, E, A, O> schedule) =>
      schedule.driver<R, E>().flatMap((driver) {
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
      schedule.driver<R, E>().flatMap((driver) {
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
        (ctx) => _run(ctx).flatMapFOr(
          (exit) => exit._matchExitFOr(
            (e) => f(Either.left(e))._run(ctx).flatMapFOr(
                  (fExit) => fExit.flatMapExit((_) => exit),
                  interruptionSignal: ctx.signal,
                ),
            Either.right,
          ),
          interruptionSignal: ctx.signal,
        ),
      );

  ZIO<R, E, A> tapExit<X>(
    ZIO<R, E, X> Function(Exit<E, A> _) f,
  ) =>
      ZIO.from(
        (ctx) => _run(ctx).flatMapFOr(
          (exit) => f(exit)._run(ctx).flatMapFOr(
                (fExit) => fExit.flatMapExit((_) => exit),
                interruptionSignal: ctx.signal,
              ),
          interruptionSignal: ctx.signal,
        ),
      );

  ZIO<R, E, A> withRuntime(Runtime runtime) =>
      ZIO.from((ctx) => _run(ctx.withRuntime(runtime)));

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
    Runtime? runtime,
    Deferred<Unit>? interruptionSignal,
  }) =>
      (runtime ?? Runtime.defaultRuntime).run(
        this,
        interruptionSignal: interruptionSignal,
      );

  Future<A> runFutureOrThrow({
    Runtime? runtime,
    Deferred<Unit>? interruptionSignal,
  }) =>
      (runtime ?? Runtime.defaultRuntime).runFutureOrThrow(
        this,
        interruptionSignal: interruptionSignal,
      );

  Future<Exit<E, A>> runFuture({
    Runtime? runtime,
    Deferred<Unit>? interruptionSignal,
  }) =>
      (runtime ?? Runtime.defaultRuntime).runFuture(
        this,
        interruptionSignal: interruptionSignal,
      );

  FutureOr<A> runOrThrow({
    Runtime? runtime,
    Deferred<Unit>? interruptionSignal,
  }) =>
      (runtime ?? Runtime.defaultRuntime).runOrThrow(
        this,
        interruptionSignal: interruptionSignal,
      );

  Exit<E, A> runSync({
    Runtime? runtime,
    Deferred<Unit>? interruptionSignal,
  }) =>
      (runtime ?? Runtime.defaultRuntime).runSync(
        this,
        interruptionSignal: interruptionSignal,
      );

  A runSyncOrThrow([Runtime? runtime]) =>
      (runtime ?? Runtime.defaultRuntime).runSyncOrThrow(this);
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
  ZIO<R, E, A> ask<R>() => ZIO.from((ctx) => _run(ctx.noEnv));

  ZIO<Scope, E, A> acquireRelease(
    IO<Unit> Function(A _) release,
  ) =>
      ask<Scope>().tapEnv((a, _) => _.addScopeFinalizer(release(a)).lift());

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
  RIOOption<R, A> filter(
    bool Function(A _) predicate,
  ) =>
      filterOrFail(predicate, (a) => const NoValue());

  RIOOption<R, B> flatMapNullable<B>(
    B? Function(A _) f,
  ) =>
      flatMapNullableOrFail(f, (a) => const NoValue());

  RIOOption<R, B> flatMapOption<B>(
    Option<B> Function(A _) f,
  ) =>
      flatMapOptionOrFail(f, (a) => const NoValue());

  RIO<R, Option<A>> get option => matchSync(
        (a) => Option.none(),
        Option.of,
      );
}

extension ZIOIterableExt<R, E, A> on Iterable<ZIO<R, E, A>> {
  ZIO<R, E, IList<A>> get collect => ZIO.collect(this);
  ZIO<R, E, Unit> get collectDiscard => ZIO.collectDiscard(this);
  ZIO<R, E, IList<A>> get collectPar => ZIO.collectPar(this);
  ZIO<R, E, Unit> get collectParDiscard => ZIO.collectParDiscard(this);
}

extension ZIOEitherExt<E, A> on Either<E, A> {
  ZIO<NoEnv, E, A> get toZIO => ZIO.fromEither(this);
}

extension ZIOOptionExt<A> on Option<A> {
  IOOption<A> get toZIO => ZIO.fromOption(this);
  ZIO<NoEnv, E, A> toZIOOrFail<E>(E Function() onNone) =>
      ZIO.fromOptionOrFail(this, onNone);
}
