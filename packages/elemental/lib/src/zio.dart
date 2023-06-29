import 'dart:async';
import 'dart:collection';

import 'package:elemental/elemental.dart';
import 'package:elemental/src/future_or.dart';
import 'package:fpdart/fpdart.dart' as fpdart;
import 'package:meta/meta.dart';

part 'zio/async.dart';
part 'zio/context.dart';
part 'zio/deferred.dart';
part 'zio/do.dart';
part 'zio/exit.dart';
part 'zio/fiber.dart';
part 'zio/layer.dart';
part 'zio/logger.dart';
part 'zio/queue.dart';
part 'zio/ref.dart';
part 'zio/runner.dart';
part 'zio/runtime.dart';
part 'zio/schedule.dart';
part 'zio/scope.dart';
part 'zio/semaphore.dart';

/// Represents the absence of an environment
class NoEnv {
  const NoEnv();

  @override
  String toString() => 'NoEnv()';
}

/// Represents an operation that cant fail, with no requirements
typedef IO<A> = ZIO<NoEnv, Never, A>;

/// Represents an operation that cant fail, with [R] requirements
typedef RIO<R, A> = ZIO<R, Never, A>;

/// Represents an operation that can fail, with no requirements
typedef EIO<E, A> = ZIO<NoEnv, E, A>;

/// Represents an operation that represent an optional value
typedef IOOption<A> = ZIO<NoEnv, None, A>;

/// Represents an operation that represent an optional value
typedef RIOOption<R, A> = ZIO<R, None, A>;

/// Represents an operation that can fail with requirements
class ZIO<R, E, A> {
  const ZIO._(
    this._unsafeRun, {
    this.stackTrace,
  });

  /// Creates a [ZIO] from a function that takes a [ZIOContext] and returns a [FutureOr] of [Exit]
  factory ZIO.from(FutureOr<Exit<E, A>> Function(ZIOContext<R> ctx) run) {
    StackTrace? stackTrace = debugTracing ? StackTrace.current : null;
    assert(() {
      stackTrace ??= StackTrace.current;
      return true;
    }());
    return ZIO._(run, stackTrace: stackTrace);
  }

  final FutureOr<Exit<E, A>> Function(ZIOContext<R> ctx) _unsafeRun;

  static var debugTracing = false;
  final StackTrace? stackTrace;

  /// Run the [ZIO] with the provided [ZIOContext].
  FutureOr<Exit<E, A>> unsafeRun(ZIOContext<R> ctx) {
    if (ctx.signal.unsafeCompleted) {
      return Exit.left(Interrupted(stackTrace));
    }

    try {
      if (stackTrace != null) {
        return _unsafeRun(ctx).then((exit) {
          if (ctx.signal.unsafeCompleted && exit is! Left<Interrupted<E>, A>) {
            return Exit.left(Interrupted(stackTrace));
          }

          return exit.mapLeft((cause) => cause.withTrace(stackTrace!));
        });
      }

      return _unsafeRun(ctx).then((exit) {
        if (ctx.signal.unsafeCompleted) {
          return Exit.left(const Interrupted());
        }

        return exit;
      });
    } catch (err, stack) {
      return Exit.left(Defect(err, stack, stackTrace));
    }
  }

  // Constructors

  /// Create a synchronous [ZIO] from a function, returning a [IO] that can't fail.
  factory ZIO(A Function() f) => ZIO.from((ctx) => Either.right(f()));

  /// Retrieves and clears the annotations for the provided key.
  static ZIO<R, E, IMap<String, dynamic>> annotations<R, E>(Symbol key) =>
      ZIO.from((ctx) => Exit.right(ctx.unsafeGetAnnotations(key)));

  /// [IO] version of [annotations].
  static IO<IMap<String, dynamic>> annotationsIO(Symbol key) =>
      annotations(key);

  factory ZIO.async(void Function(AsyncContext<E, A> resume) f) =>
      ZIO.from((ctx) {
        final context = AsyncContext<E, A>();
        f(context);
        return context._deferred.await().unsafeRun(ctx);
      });

  factory ZIO.asyncInterrupt(IO<Unit> Function(AsyncContext<E, A> $) f) =>
      ZIO.from((ctx) {
        final context = AsyncContext<E, A>();
        final finalizer = f(context);
        if (context._deferred.unsafeCompleted) {
          return context._deferred.await().unsafeRun(ctx);
        }

        final interuption =
            ctx.signal.await<R>().alwaysIgnore(finalizer.lift());

        return context._deferred
            .await<R>()
            .race(interuption)
            .unsafeRun(ctx.withoutSignal);
      });

  /// Create a [ZIO] that succeeds with [a].
  factory ZIO.succeed(A a) => ZIO.fromEither(Either.right(a));

  /// Create a [ZIO] that fails with [e].
  factory ZIO.fail(E e) => ZIO.fromEither(Either.left(e));

  /// Create a [ZIO] that fails with the given [cause].
  factory ZIO.failCause(Cause<E> cause) => ZIO.fromExit(Either.left(cause));

  /// Create a [ZIO] that fails with the given defect.
  factory ZIO.die(dynamic defect) =>
      ZIO.fromExit(Either.left(Defect(defect, StackTrace.current)));

  /// Runs the given [zios] in sequence, collecting the results.
  static ZIO<R, E, IList<A>> collect<R, E, A>(Iterable<ZIO<R, E, A>> zios) =>
      ZIO.traverseIterable<R, E, ZIO<R, E, A>, A>(
        zios,
        identity,
      );

  /// Runs the given [zios] in sequence, discarding the results.
  static ZIO<R, E, Unit> collectDiscard<R, E, A>(Iterable<ZIO<R, E, A>> zios) =>
      collect(zios).asUnit;

  /// Runs the given [zios] in parallel, collecting the results.
  static ZIO<R, E, IList<A>> collectPar<R, E, A>(Iterable<ZIO<R, E, A>> zios) =>
      ZIO.traverseIterablePar<R, E, ZIO<R, E, A>, A>(
        zios,
        identity,
      );

  /// Runs the given [zios] in parallel, discarding the results.
  static ZIO<R, E, Unit> collectParDiscard<R, E, A>(
    Iterable<ZIO<R, E, A>> zios,
  ) =>
      collectPar(zios).asUnit;

  /// Do notation for [ZIO]. You can use async/await to write your code in a
  /// imperative style.
  ///
  /// ```dart
  /// ZIO.Do(($, env) async {
  ///   final a = await $(ZIO.succeed(1));
  ///   final b = await $(ZIO.succeed(2));
  ///   return a + b;
  /// });
  /// ```
  // ignore: non_constant_identifier_names
  factory ZIO.Do(DoFunction<R, E, A> f) => ZIO.from((ctx) => fromThrowable(
        () => f(DoContext(ctx), ctx.env),
        onError: (err, stack) {
          if (err is Cause<E>) {
            return err;
          }

          return Defect(err, stack);
        },
      ));

  /// Retrieve the current environment of the [ZIO].
  static RIO<R, R> env<R>() => ZIO.from((ctx) => Either.right(ctx.env));

  /// Retrieve the current environment of the [ZIO] and pass it to the given
  /// function, returning the result.
  factory ZIO.envWith(A Function(R env) f) =>
      ZIO.from((ctx) => Either.right(f(ctx.env)));

  /// Retrieve the current environment of the [ZIO] and pass it to the given
  /// function, returning the result of the resulting [ZIO].
  factory ZIO.envWithZIO(ZIO<NoEnv, E, A> Function(R env) f) =>
      ZIO.from((ctx) => f(ctx.env).unsafeRun(ctx.noEnv));

  /// Create a [ZIO] from the given [Either], succeeding when it is a [Right],
  /// and failing when it is a [Left].
  factory ZIO.fromEither(Either<E, A> ea) => ZIO.fromExit(ea.toExit());

  /// Create a [ZIO] from the given [Exit].
  factory ZIO.fromExit(Exit<E, A> ea) => ZIO.from((ctx) => ea);

  /// Create an [IOOption] from the given nullable value, succeeding when it is
  /// not null, and failing with [None] when it is null.
  static IOOption<A> fromNullable<A>(A? a) =>
      ZIO.fromOption(Option.fromNullable(a));

  /// Create a [EIO] from the given nullable value, succeeding when it is not
  /// null, and failing with the result of [onNull] when it is null.
  factory ZIO.fromNullableOrFail(A? a, E Function() onNull) =>
      ZIO.fromOptionOrFail(Option.fromNullable(a), onNull);

  /// Create an [IOOption] from the given [Option], succeeding when it is a
  /// [Some], and failing with [None] when it is a [None].
  static IOOption<A> fromOption<A>(Option<A> oa) => ZIO.fromEither(oa.match(
        () => Either.left(const None()),
        Either.right,
      ));

  /// Create a [EIO] from the given [Option], succeeding when it is a [Some],
  /// and failing with the result of [onNone] when it is a [None].
  factory ZIO.fromOptionOrFail(
    Option<A> oa,
    E Function() onNone,
  ) =>
      ZIO.syncEither(() => oa.toEither(() => onNone()));

  /// Creates a ZIO from a [Future].
  ///
  /// **This can be unsafe** because it will throw an error if the future fails.
  factory ZIO.future(FutureOr<A> Function() f) => ZIO.from(
        (ctx) => fromThrowable(
          f,
          onError: (e, s) => Defect(e, s),
        ),
      );

  /// Access a [Layer] and return the resulting service.
  /// If the [Layer] has already been accessed or provided with [provideLayer],
  /// the cached value will be used.
  factory ZIO.layer(Layer<E, A> layer) =>
      ZIO.from((ctx) => ctx.accessLayer<E, A>(layer).unsafeRun(ctx));

  /// Create a [ZIO] lazily with the given function.
  /// Useful for when you need to create a [ZIO] from a synchronous side-effect.
  factory ZIO.lazy(ZIO<R, E, A> Function() zio) =>
      ZIO.from((ctx) => zio().unsafeRun(ctx));

  /// Log a message using the [Logger] service. It uses the [loggerLayer] to access
  /// the [Logger].
  static ZIO<R, E, Unit> log<R, E>(
    LogLevel level,
    Object? message, {
    Map<String, dynamic>? annotations,
  }) =>
      ZIO.from((ctx) => ctx
          .accessLayer<E, Logger>(loggerLayer)
          .flatMap(
            (log) => log.log(
              level,
              DateTime.now(),
              message.toString(),
              annotations: ctx
                  .unsafeGetAnnotations(loggerAnnotationsSymbol)
                  .addMap(annotations ?? {}),
            ),
          )
          .unsafeRun(ctx));

  /// An [IO] version of [log].
  static IO<Unit> logIO(LogLevel level, Object? message) => log(level, message);

  /// Log a message at the [LogLevel.debug] level using the [Logger] service.
  static ZIO<R, E, Unit> logDebug<R, E>(
    Object? message, {
    Map<String, dynamic>? annotations,
  }) =>
      log(LogLevel.debug, message, annotations: annotations);

  /// An [IO] version of [logDebug].
  static IO<Unit> logDebugIO(
    Object? message, {
    Map<String, dynamic>? annotations,
  }) =>
      logDebug(message, annotations: annotations);

  /// Log a message at the [LogLevel.info] level using the [Logger] service.
  static ZIO<R, E, Unit> logInfo<R, E>(
    Object? message, {
    Map<String, dynamic>? annotations,
  }) =>
      log(LogLevel.info, message, annotations: annotations);

  /// An [IO] version of [logInfo].
  static IO<Unit> logInfoIO(
    Object? message, {
    Map<String, dynamic>? annotations,
  }) =>
      logInfo(message, annotations: annotations);

  /// Log a message at the [LogLevel.warn] level using the [Logger] service.
  static ZIO<R, E, Unit> logWarn<R, E>(
    Object? message, {
    Map<String, dynamic>? annotations,
  }) =>
      log(LogLevel.warn, message, annotations: annotations);

  /// An [IO] version of [logWarn].
  static IO<Unit> logWarnIO(
    Object? message, {
    Map<String, dynamic>? annotations,
  }) =>
      logWarn(message, annotations: annotations);

  /// Log a message at the [LogLevel.error] level using the [Logger] service.
  static ZIO<R, E, Unit> logError<R, E>(
    Object? message, {
    Map<String, dynamic>? annotations,
  }) =>
      log(LogLevel.error, message, annotations: annotations);

  /// An [IO] version of [logError].
  static IO<Unit> logErrorIO(
    Object? message, {
    Map<String, dynamic>? annotations,
  }) =>
      logError(message, annotations: annotations);

  factory ZIO.raceAll(Iterable<ZIO<R, E, A>> others) => ZIO.from((ctx) {
        final signal = DeferredIO<Never>();
        final deferred = Deferred<E, A>();

        for (final zio in others) {
          zio
              .unsafeRun(ctx.withSignal(signal))
              .then(deferred.unsafeCompleteExit);
          if (deferred.unsafeCompleted) {
            break;
          }
        }

        return deferred.await<R>().unsafeRun(ctx).then(
              (exit) => signal
                  .failCause(const Interrupted())
                  .unsafeRun(ctx.withoutSignal)
                  .then((_) => exit),
            );
      });

  /// Access the current [Runtime].
  static ZIO<R, E, Runtime> runtime<R, E>() => ZIO
      .from((ctx) => Either.right(ctx.runtime.mergeLayerContext(ctx.layers)));

  /// An [IO] version of [runtime].
  static final IO<Runtime> runtimeIO = runtime();

  /// Sleep for the given [duration].
  static ZIO<R, E, Unit> sleep<R, E>(Duration duration) =>
      ZIO.future(() => Future.delayed(duration, () => fpdart.unit));

  /// An [IO] version of [sleep].
  static IO<Unit> sleepIO(Duration duration) => sleep(duration);

  /// Create a [EIO] from the resulting [Either], succeeding when it is a [Right],
  /// and failing with the [Left] value when it is a [Left].
  factory ZIO.syncEither(Either<E, A> Function() f) =>
      ZIO.from((ctx) => f().toExit());

  /// Create a [EIO] from the resulting [Exit] value;
  factory ZIO.syncExit(Exit<E, A> Function() f) => ZIO.from((ctx) => f());

  /// Traverse an [Iterable] with the given function, collecting the results.
  static ZIO<R, E, IList<B>> traverseIterable<R, E, A, B>(
    Iterable<A> iterable,
    ZIO<R, E, B> Function(A _) f,
  ) =>
      ZIO.from((ctx) {
        if (iterable.isEmpty) {
          return Exit.right(IList());
        }

        return iterable
            .map((a) => f(a))
            .fold<ZIO<R, E, IList<B>>>(
              ZIO.succeed(IList()),
              (acc, zio) => acc.zipWith(zio, (a, B b) => a.add(b)),
            )
            .unsafeRun(ctx);
      });

  /// Traverse an [Iterable] with the given function, collecting the results in
  /// parallel.
  static ZIO<R, E, IList<B>> traverseIterablePar<R, E, A, B>(
    Iterable<A> iterable,
    ZIO<R, E, B> Function(A _) f,
  ) =>
      ZIO.from((ctx) {
        if (iterable.isEmpty) {
          return Exit.right(IList());
        }

        final failure = Deferred<E, Never>();
        final results = iterable
            .map((a) => f(a)
                .tapErrorCause(failure.failCause)
                .race(failure.await())
                .unsafeRun(ctx))
            .toList(growable: false);
        final hasFuture = results.any((eb) => eb is Future);

        if (!hasFuture) {
          return Either.sequenceList(
            results.cast<Exit<E, B>>().toList(growable: false),
          ).map((a) => a.toIList());
        }

        return Future.wait(results.map((eb) => Future.value(eb))).then(
          (eithers) => Either.sequenceList(eithers).map((a) => a.toIList()),
        );
      });

  /// Create a [EIO] from the given function [f], which may throw an exception.
  ///
  /// If the function throws an exception, the [EIO] will fail with the result of
  /// calling [onError] with the exception and stack trace.
  ///
  /// Otherwise, the [EIO] will succeed with the result.
  factory ZIO.tryCatch(
    FutureOr<A> Function() f,
    E Function(dynamic error, StackTrace stackTrace) onError,
  ) =>
      ZIO.from(
        (ctx) => fromThrowable(
          f,
          onError: (e, s) => Failure(onError(e, s)),
        ),
      );

  /// A variant of [ZIO.tryCatch] that provides the current environment [R] to the
  /// function [f].
  factory ZIO.tryCatchEnv(
    FutureOr<A> Function(R env) f,
    E Function(dynamic error, StackTrace stackTrace) onError,
  ) =>
      ZIO.from(
        (ctx) => fromThrowable(
          () => f(ctx.env),
          onError: (e, s) => Failure(onError(e, s)),
        ),
      );

  static IOOption<A> tryCatchNullable<A>(
    FutureOr<A?> Function() f,
  ) =>
      ZIO.tryCatchOption(f).flatMapNullable(identity);

  /// A variant of [ZIO.tryCatch], that returns an [IOOption] instead of an [EIO].
  ///
  /// Failures are mapped to [None].
  static IOOption<A> tryCatchOption<A>(
    FutureOr<A> Function() f,
  ) =>
      ZIO.tryCatch(f, (_, s) => const None());

  /// For the const unit
  static FutureOr<Exit<E, Unit>> _kZioUnit<R, E>(ZIOContext<R> ctx) =>
      const Right(fpdart.unit);

  /// Returns a [ZIO] that succeeds with [unit].
  static ZIO<R, E, Unit> unit<R, E>() => const ZIO._(_kZioUnit);

  /// An [IO] version of [unit].
  static const unitIO = IO._(_kZioUnit);

  // ==========================
  // ==== Instance methods ====
  // ==========================

  /// Always run the given [ZIO] after this one, regardless of success or failure.
  ZIO<R, E, A> always(ZIO<R, E, A> zio) =>
      ZIO.from((ctx) => unsafeRun(ctx).then(
            (exit) => zio.unsafeRun(ctx.withoutSignal),
          ));

  /// Always run the given [ZIO] after this one, regardless of success or failure.
  ///
  /// The result of this [ZIO] is ignored.
  ZIO<R, E, A> alwaysIgnore<X>(ZIO<R, E, X> zio) => ZIO.from(
        (ctx) => race(ctx.signal.awaitIO.lift<R, E>()).unsafeRun(ctx).then(
              (exit) =>
                  zio.unsafeRun(ctx.withoutSignal).then((_) => _.call(exit)),
            ),
      );

  /// Adds an annotation to the the current [ZIOContext], which can be retrieved
  /// later with [annotations].
  ZIO<R, E, A> annotate(Symbol key, String name, dynamic value) =>
      ZIO.from((ctx) => unsafeRun(ctx.unsafeAnnotate(key, name, value)));

  /// Adds an annotation to the next log entry.
  ZIO<R, E, A> annotateLog(String name, dynamic value) =>
      annotate(loggerAnnotationsSymbol, name, value);

  /// Maps the success value of this [ZIO] to the given constant [b].
  ZIO<R, E, B> as<B>(B b) => map((_) => b);

  /// Maps the success value of this [ZIO] to [unit].
  ZIO<R, E, Unit> get asUnit => as(fpdart.unit);

  ZIO<R, E2, A> _mapCauseFOr<E2>(
    FutureOr<Exit<E2, A>> Function(
      ZIOContext<R>,
      Cause<E> _,
    ) f,
  ) =>
      ZIO.from(
        (ctx) => unsafeRun(ctx).then(
          (exit) => exit.match((cause) => f(ctx, cause), Exit.right),
        ),
      );

  /// Catch all defects that may occur on this [ZIO]. The result will be replaced
  /// by executing the [ZIO] resulting from the given function.
  ZIO<R, E2, A> catchCause<E2>(
    ZIO<R, E2, A> Function(Cause<E> _) f,
  ) =>
      _mapCauseFOr((ctx, _) => f(_).unsafeRun(ctx));

  /// Catch any [Defect]'s that may occur on this [ZIO]. The result will be
  /// replaced by executing the [ZIO] resulting from the given function.
  ZIO<R, E2, A> catchDefect<E2>(
    ZIO<R, E2, A> Function(Defect<E> _) f,
  ) =>
      _mapCauseFOr(
        (ctx, _) =>
            _ is Defect<E> ? f(_).unsafeRun(ctx) : Either.left(_.lift()),
      );

  /// Catch any errors that may occur on this [ZIO]. The result will be
  /// replaced by executing the [ZIO] resulting from the given function.
  ZIO<R, E2, A> catchError<E2>(
    ZIO<R, E2, A> Function(E _) f,
  ) =>
      _mapCauseFOr(
        (ctx, _) =>
            _ is Failure<E> ? f(_.error).unsafeRun(ctx) : Either.left(_.lift()),
      );

  /// Delay the evaluation of this [ZIO] by the given [duration].
  ///
  /// The delay will occur **before** the [ZIO] is evaluated.
  ZIO<R, E, A> delay(Duration duration) =>
      ZIO.sleep<R, E>(duration).zipRight(this);

  /// Squashes the error and success channels into a single [Either] result.
  RIO<R, Either<E, A>> get either => ZIO.from((ctx) => unsafeRun(ctx).then(
        (exit) => exit.matchExit(
          (_) => Either.right(Either.left(_)),
          (_) => Either.right(Either.right(_)),
        ),
      ));

  /// Filters the success value of this [ZIO] with the given [predicate], failing
  /// with [onFalse] if the predicate fails.
  ZIO<R, E, A> filterOrFail(
    bool Function(A _) predicate,
    E Function(A _) onFalse,
  ) =>
      flatMapEither((a) => Either.fromPredicate(a, predicate, onFalse));

  /// Passes the success value of this [ZIO] to the given function, and replaces
  /// the result by executing the resulting [ZIO].
  ZIO<R, E, B> flatMap<B>(
    ZIO<R, E, B> Function(A _) f,
  ) =>
      ZIO.from(
        (ctx) => unsafeRun(ctx).then(
          (ea) => ea.match(
            (e) => Either.left(e),
            (a) => f(a).unsafeRun(ctx),
          ),
        ),
      );

  /// A variant of [flatMap] that zip's the result of this [ZIO] with the result
  /// of the given [ZIO], returning a record of the results.
  ZIO<R, E, (A, B)> flatMap2<B>(
    ZIO<R, E, B> Function(A _) f,
  ) =>
      flatMap((a) => f(a).map((b) => (a, b)));

  /// A variant of [flatMap] that uses the resulting [Either] to determine
  /// the result.
  ///
  /// [Right] values are mapped to the success channel, [Left] values are
  /// mapped to the error channel.
  ZIO<R, E, B> flatMapEither<B>(
    Either<E, B> Function(A _) f,
  ) =>
      ZIO.from(
        (ctx) => unsafeRun(ctx).then(
          (ea) => ea.flatMapExitEither(f),
        ),
      );

  /// A variant of [flatMap] that also provides the environment to the given
  /// function.
  ZIO<R, E, B> flatMapEnv<B>(
    ZIO<R, E, B> Function(A _, R env) f,
  ) =>
      ZIO.from(
        (ctx) => unsafeRun(ctx).then(
          (ea) => ea.match(
            (e) => Either.left(e),
            (a) => f(a, ctx.env).unsafeRun(ctx),
          ),
        ),
      );

  /// A variant of [flatMap] that determines the result of the [ZIO] by
  /// evaluating the resulting nullable value.
  ///
  /// If the value is `null`, the resulting [ZIO] will fail with [onNull].
  ZIO<R, E, B> flatMapNullableOrFail<B>(
    B? Function(A _) f,
    E Function(A _) onNull,
  ) =>
      flatMapEither((a) => Either.fromNullable(f(a), () => onNull(a)));

  /// A variant of [flatMap] that uses the resulting [Option] to determine
  /// the result.
  ///
  /// [Some] values are mapped to the success channel, and if the value is
  /// [None], the resulting [ZIO] will fail with [onNone].
  ZIO<R, E, B> flatMapOptionOrFail<B>(
    Option<B> Function(A _) f,
    E Function(A _) onNone,
  ) =>
      flatMapEither((a) => Either.fromOption(f(a), () => onNone(a)));

  /// A variant of [flatMap] that uses the result of the given function. If the given
  /// function throws an error, the resulting [ZIO] will fail with the result of
  /// [onThrow].
  ZIO<R, E, B> flatMapThrowable<B>(
    FutureOr<B> Function(A _) f,
    E Function(dynamic error, StackTrace stack) onThrow,
  ) =>
      flatMap((a) => ZIO.tryCatch(() => f(a), onThrow));

  /// A variant of [flatMapThrowable], that also provides the environment to the given
  /// function.
  ZIO<R, E, B> flatMapThrowableEnv<B>(
    FutureOr<B> Function(A _, R env) f,
    E Function(dynamic error, StackTrace stack) onThrow,
  ) =>
      flatMapEnv((a, env) => ZIO.tryCatch(() => f(a, env), onThrow));

  /// Executes the [ZIO] in a loop forever, until it fails.
  ZIO<R, E, Never> get forever {
    ZIO<R, E, Never> loop() => flatMap((_) => loop());
    return loop();
  }

  /// Succeed with the value of this [ZIO] if it succeeds, or succeed with the
  /// result of the given function if it fails.
  RIO<R, A> getOrElse(
    A Function(E _) orElse,
  ) =>
      matchSync(orElse, identity);

  /// Succeed with the value of this [ZIO] if it succeeds, or succeed with [null]
  /// if it fails.
  RIO<R, A?> get getOrNull => matchSync((e) => null, identity);

  /// Ignore both the success and failure values of this [ZIO].
  RIO<R, Unit> get ignore => matchSync((e) => fpdart.unit, (a) => fpdart.unit);

  /// Ignore both the success and failure values of this [ZIO], and log any
  /// failure using [logInfo].
  RIO<R, Unit> get ignoreLogged => logged.ignore;

  /// Log any failures using [logInfo].
  ZIO<R, E, A> get logged => tapErrorCause(logInfo);

  /// Succeed with the value of this [ZIO] if it succeeds, or succeed with the
  /// result of the given function if it fails.
  ///
  /// On failure, the error is logged using [logInfo].
  RIO<R, A> logOrElse(
    A Function(E _) orElse,
  ) =>
      tapError(logInfo).getOrElse(orElse);

  /// Transform the success value of this [ZIO] using the given function.
  ZIO<R, E, B> map<B>(
    B Function(A _) f,
  ) =>
      ZIO.from((ctx) => unsafeRun(ctx).then((ea) => ea.map(f)));

  /// Transform the failure value of this [ZIO] using the given function.
  ZIO<R, E2, A> mapError<E2>(
    E2 Function(E _) f,
  ) =>
      ZIO.from((ctx) => unsafeRun(ctx).then(
            (ea) => ea.mapFailure(f),
          ));

  /// Reduce the success and error values of this [ZIO] using the given
  /// functions.
  ZIO<R, E2, B> match<E2, B>(
    ZIO<R, E2, B> Function(E _) onError,
    ZIO<R, E2, B> Function(A _) onSuccess,
  ) =>
      ZIO.from(
        (ctx) => unsafeRun(ctx).then(
          (ea) => ea._matchExitFOr(
            (e) => onError(e).unsafeRun(ctx),
            (a) => onSuccess(a).unsafeRun(ctx),
          ),
        ),
      );

  /// A synchronous version of [match].
  RIO<R, B> matchSync<B>(
    B Function(E _) onError,
    B Function(A _) onSuccess,
  ) =>
      ZIO.from(
        (ctx) => unsafeRun(ctx).then(
          (ea) => ea.matchExit(
            (e) => Either.right(onError(e)),
            (a) => Either.right(onSuccess(a)),
          ),
        ),
      );

  /// Memoize the result of this [ZIO] in a [Deferred].
  ///
  /// The result will be computed only once, and subsequent calls will return
  /// the same value.
  IO<ZIO<R, E, A>> get memoize => IO(() {
        final deferred = Deferred<E, A>();
        var executed = false;

        return ZIO<R, E, A>.from((ctx) {
          if (executed) {
            return deferred.await().unsafeRun(ctx);
          }

          executed = true;
          return tapExit(deferred.completeExit).unsafeRun(ctx);
        });
      });

  /// Force a synchronous [ZIO] to run asynchronously.
  ZIO<R, E, A> get microtask =>
      ZIO.from((ctx) => Future.microtask(() => unsafeRun(ctx)));

  RIOOption<R, A> get option => mapError((_) => const None());

  /// If the [ZIO] fails, turn the failure into a defect.
  RIO<R, A> get orDie => _mapCauseFOr((ctx, _) => _ is Failure<E>
      ? Exit.left(Defect(_, StackTrace.current))
      : Exit.left(_.lift()));

  /// Provide the [ZIO] with its required environment, which eliminates its
  /// dependency on [R].
  EIO<E, A> provide(R env) {
    final zio = env is ScopeMixin && !env.scopeClosable
        ? alwaysIgnore(env.closeScope())
        : this;
    return ZIO.from((ctx) => zio.unsafeRun(ctx.withEnv(env)));
  }

  /// Provide the [ZIO] with a [Layer], building it and adding it into the context.
  ///
  /// If the [Layer] already exists in the context, it will be replaced.
  ZIO<R, E, A> provideLayer(Layer<E, dynamic> layer) =>
      ZIO.from((ctx) => ctx.provideLayer(layer).zipRight(this).unsafeRun(ctx));

  ZIO<R, E, A> provideLayerContext(LayerContext context) =>
      ZIO.from((ctx) => unsafeRun(ctx._mergeLayerContext(context)));

  /// Provide the [ZIO] with a [Layer], using the provided pre-built service [S].
  ZIO<R, E, A> Function(S service) provideService<S>(Layer<dynamic, S> layer) =>
      (service) => ZIO.from(
            (ctx) => ctx
                .provideService<E, S>(layer, service)
                .zipRight(this)
                .unsafeRun(ctx),
          );

  ZIO<R, E, A> race(ZIO<R, E, A> other) => ZIO.raceAll([this, other]);

  /// Repeat this [ZIO] using the given [Schedule].
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

  /// Repeat this [ZIO] [n] times.
  ZIO<R, E, A> repeatN(int n) =>
      flatMap((_) => n > 0 ? repeatN(n - 1) : ZIO.succeed(_));

  /// Repeat this [ZIO] while the given predicate is true.
  ZIO<R, E, A> repeatWhile(
    bool Function(A _) predicate,
  ) =>
      flatMap((_) => predicate(_) ? repeatWhile(predicate) : ZIO.succeed(_));

  /// Retry this [ZIO] if it fails using the given [Schedule].
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

  /// Retry (repeat on failure) this [ZIO] [n] times.
  ZIO<R, E, A> retryN(int n) =>
      catchError((_) => n > 0 ? retryN(n - 1) : ZIO.fail(_));

  /// Retry this [ZIO] when it fails while the given predicate is true.
  ZIO<R, E, A> retryWhile(
    bool Function(E _) predicate,
  ) =>
      catchError((_) => predicate(_) ? retryWhile(predicate) : ZIO.fail(_));

  /// Like [flatMap], but the result of the resulting [ZIO] is discarded.
  ZIO<R, E, A> tap<X>(
    ZIO<R, E, X> Function(A _) f,
  ) =>
      flatMap((a) => f(a).as(a));

  /// A variant of [tap], where the current environment is passed to the
  /// function.
  ZIO<R, E, A> tapEnv<X>(
    ZIO<R, E, X> Function(A _, R env) f,
  ) =>
      flatMapEnv((a, env) => f(a, env).as(a));

  /// Like [catchError], but the result of the resulting [ZIO] is discarded.
  ZIO<R, E, A> tapError<X>(
    ZIO<R, E, X> Function(E _) f,
  ) =>
      catchError((e) => f(e).zipRight(ZIO.fail(e)));

  /// Like [catchCause], but the result of the resulting [ZIO] is discarded.
  ZIO<R, E, A> tapErrorCause<X>(
    ZIO<R, E, X> Function(Cause<E> _) f,
  ) =>
      catchCause((e) => f(e).zipRight(ZIO.failCause(e)));

  /// A variant of [tap], where the success and failure channels are merged into
  /// an [Either].
  ZIO<R, E, A> tapEither<X>(
    ZIO<R, E, X> Function(Either<E, A> _) f,
  ) =>
      ZIO.from(
        (ctx) => unsafeRun(ctx).then(
          (exit) => exit
              ._matchExitFOr(
                (e) => f(Either.left(e)).unsafeRun(ctx),
                (a) => f(Either.right(a)).unsafeRun(ctx),
              )
              .then((fExit) => fExit.flatMapExit((_) => exit)),
        ),
      );

  /// A variant of [tap], passing the [Exit] value of this [ZIO].
  ZIO<R, E, A> tapExit<X>(
    ZIO<R, E, X> Function(Exit<E, A> _) f,
  ) =>
      ZIO.from(
        (ctx) => race(ctx.signal.awaitIO.lift<R, E>()).unsafeRun(ctx).then(
              (exit) => f(exit)
                  .unsafeRun(ctx.withoutSignal)
                  .then((_) => _.call(exit)),
            ),
      );

  ZIO<R, E, A> timeout(
    Duration duration,
  ) =>
      race(ZIO<R, E, A>.failCause(const Interrupted()).delay(duration));

  /// Replace the [Runtime] in this [ZIO] with the given [Runtime].
  ZIO<R, E, A> withRuntime(Runtime runtime) =>
      ZIO.from((ctx) => unsafeRun(ctx.withRuntime(runtime)));

  /// Combine the result of this [ZIO] with the result of the given [ZIO], returning
  /// a tuple of the results.
  ZIO<R, E, (A, B)> zip<B>(ZIO<R, E, B> zio) =>
      zipWith(zio, (a, B b) => (a, b));

  /// Combine the result of this [ZIO] with the result of the given [ZIO], returning
  /// a tuple of the results.
  ///
  /// The [ZIO]'s are run in parallel.
  ZIO<R, E, (A, B)> zipPar<B>(ZIO<R, E, B> zio) =>
      zipParWith(zio, (a, B b) => (a, b));

  /// Run this [ZIO] and the given [ZIO] in parallel, ignoring the result of the
  /// given [ZIO].
  ZIO<R, E, A> zipParLeft<B>(ZIO<R, E, B> zio) =>
      zipParWith(zio, (a, B b) => a);

  /// Run this [ZIO] and the given [ZIO] in parallel, only returning the result of
  /// the given [ZIO].
  ZIO<R, E, B> zipParRight<B>(ZIO<R, E, B> zio) =>
      zipParWith(zio, (a, B b) => b);

  /// Combine the result of this [ZIO] with the result of the given [ZIO], using
  /// the given function to determine the result.
  ///
  /// The [ZIO]'s are run in parallel.
  ZIO<R, E, C> zipParWith<B, C>(
    ZIO<R, E, B> zio,
    C Function(A a, B b) resolve,
  ) =>
      ZIO.collectPar([this, zio]).map((a) => resolve(a[0] as A, a[1] as B));

  /// Run this [ZIO] and the given [ZIO] sequentially, ignoring the result of the
  /// given [ZIO].
  ZIO<R, E, A> zipLeft<X>(ZIO<R, E, X> zio) => tap((a) => zio);

  /// Run this [ZIO] and the given [ZIO] sequentially, only returning the result of
  /// the given [ZIO].
  ///
  /// Almost identical to [flatMap];
  ZIO<R, E, B> zipRight<B>(ZIO<R, E, B> zio) => flatMap((a) => zio);

  /// Combine the result of this [ZIO] with the result of the given [ZIO], using
  /// the given function to determine the result.
  ZIO<R, E, C> zipWith<B, C>(ZIO<R, E, B> zio, C Function(A a, B b) resolve) =>
      flatMap((a) => zio.map((b) => resolve(a, b)));
}

extension ZIORunExt<E, A> on EIO<E, A> {
  /// Runs this [ZIO] asynchronously or synchronously as a [FutureOr], returning the [Exit] result.
  FutureOr<Exit<E, A>> run({
    Runtime? runtime,
    DeferredIO<Never>? interruptionSignal,
  }) =>
      (runtime ?? Runtime.defaultRuntime).run(
        this,
        interruptionSignal: interruptionSignal,
      );

  /// Runs this [ZIO] asynchronously and returns result as a [Future]. If the [ZIO] fails, the [Future] will throw.
  Future<A> runFutureOrThrow({
    Runtime? runtime,
    DeferredIO<Never>? interruptionSignal,
  }) =>
      (runtime ?? Runtime.defaultRuntime).runFutureOrThrow(
        this,
        interruptionSignal: interruptionSignal,
      );

  /// Runs this [ZIO] asynchronously and returns the [Exit] result as a [Future].
  Future<Exit<E, A>> runFuture({
    Runtime? runtime,
    DeferredIO<Never>? interruptionSignal,
  }) =>
      (runtime ?? Runtime.defaultRuntime).runFuture(
        this,
        interruptionSignal: interruptionSignal,
      );

  /// Runs this [ZIO] synchronously or asynchronously as a [FutureOr], throwing if it fails.
  FutureOr<A> runOrThrow({
    Runtime? runtime,
    DeferredIO<Never>? interruptionSignal,
  }) =>
      (runtime ?? Runtime.defaultRuntime).runOrThrow(
        this,
        interruptionSignal: interruptionSignal,
      );

  /// Runs this [ZIO] synchronously and returns the result as an [Exit].
  Exit<E, A> runSync({
    Runtime? runtime,
    DeferredIO<Never>? interruptionSignal,
  }) =>
      (runtime ?? Runtime.defaultRuntime).runSync(
        this,
        interruptionSignal: interruptionSignal,
      );

  /// Runs this [ZIO] synchronously and throws if it fails.
  A runSyncOrThrow([Runtime? runtime]) =>
      (runtime ?? Runtime.defaultRuntime).runSyncOrThrow(this);
}

extension IOLiftExt<A> on IO<A> {
  /// Lift this [IO] to a [ZIO] with the specified environment and error type.
  ZIO<R, E, A> lift<R, E>() => ask<R>().mapError((_) => _ as E);

  /// Lift this [IO] to a [EIO] with the specified error type.
  EIO<E, A> liftError<E>() => lift<NoEnv, E>();
}

extension EIOLiftExt<E extends Object?, A> on EIO<E, A> {
  /// Lift this [EIO] to a [ZIO] with the same error type.
  ZIO<R, E, A> lift<R>() => ask<R>();

  /// Lift this [EIO] to a another [EIO] with the specified error type.
  EIO<E2, A> liftError<E2>() => mapError((e) => e as E2);
}

extension RIOLiftExt<R extends Object?, A> on RIO<R, A> {
  /// Lift this [RIO] to a [ZIO] with the same environment and error type.
  ZIO<R, E, A> lift<E>() => mapError((_) => _ as E);

  /// Lift this [RIO] to a [ZIO] with the same environment and error type.
  ZIO<R, E, A> liftError<E>() => lift<E>();
}

extension ZIOLiftScopeExt<E, A> on ZIO<Scope<NoEnv>, E, A> {
  ZIO<R, E, A> liftScope<R extends ScopeMixin>() =>
      ZIO.from((ctx) => unsafeRun(ctx.withEnv(_ScopeProxy(ctx.env))));
}

extension ZIOFinalizerExt<R extends ScopeMixin, E, A> on ZIO<R, E, A> {
  /// Add a finalizer to this [ZIO] for the current [Scope], using the result of this [ZIO].
  ZIO<R, E, A> acquireRelease(
    IO<Unit> Function(A _) release,
  ) =>
      tap((a) => addFinalizer(release(a)));

  /// Add a finalizer to this [ZIO] for the current [Scope].
  ZIO<R, E, A> addFinalizer(
    IO<Unit> release,
  ) =>
      tapEnv((_, env) => env.addScopeFinalizer(release));

  /// Fork this [ZIO] into a [Fiber], running it in the background.
  ///
  /// When the scope closes, the fiber will be interrupted.
  ZIO<R, E2, Fiber<R, E, A>> forkScope<E2>() =>
      fork<E2>().acquireRelease((_) => _.interruptIO);

  /// An [IO] version of [fork].
  RIO<R, Fiber<R, E, A>> get forkScopeIO => forkScope();
}

extension ZIOAskExt<E, A> on ZIO<NoEnv, E, A> {
  /// Lift the environment of this [ZIO] to the given [R] type.
  ZIO<R, E, A> ask<R>() => ZIO.from((ctx) => unsafeRun(ctx.noEnv));
}

extension ZIOFinalizerNoEnvExt<R, E, A> on ZIO<R, E, A> {
  /// Wrap the environment of this [ZIO] in a [Scope].
  ///
  /// This is useful when you want to add finalizers to clean up resources.
  ZIO<Scope<R>, E, A> get withScope =>
      ZIO<Scope<R>, E, A>.from((ctx) => unsafeRun(ctx.withEnv(ctx.env.env)));

  /// Request a [Scope] and add a finalizer from the result of this [ZIO] to it.
  ZIO<Scope<R>, E, A> acquireRelease(
    IO<Unit> Function(A _) release,
  ) =>
      withScope.tapEnv((a, _) => _.addScopeFinalizer(release(a)));

  /// Request a [Scope] and add a finalizer to it.
  ZIO<Scope<R>, E, A> addFinalizer(
    IO<Unit> release,
  ) =>
      withScope.tapEnv((_, env) => env.addScopeFinalizer(release));
}

extension ZIOScopeExt<R, E, A> on ZIO<Scope<R>, E, A> {
  /// Provide a [Scope] to this [ZIO].
  /// All finalizers added to the [Scope] will be run at this point of the execution.
  ZIO<R, E, A> get scoped => ZIO.from((ctx) {
        final scope = Scope.withEnv(ctx.env);
        return alwaysIgnore(scope.closeScope()).unsafeRun(ctx.withEnv(scope));
      });
}

extension ZIONoneExt<R, A> on RIOOption<R, A> {
  /// Filter a [IOOption] by the given predicate, failing with [None] if the
  /// predicate is not satisfied.
  RIOOption<R, A> filter(
    bool Function(A _) predicate,
  ) =>
      filterOrFail(predicate, (a) => const None());

  /// If the given function [f] returns `null`, fail with [None].
  /// Otherwise, return the result of [f].
  RIOOption<R, B> flatMapNullable<B>(
    B? Function(A _) f,
  ) =>
      flatMapNullableOrFail(f, (a) => const None());

  /// If the given function [f] returns [None], fail with [None].
  /// Otherwise, return the result of [f].
  RIOOption<R, B> flatMapOption<B>(
    Option<B> Function(A _) f,
  ) =>
      flatMapOptionOrFail(f, (a) => const None());

  /// Transform an [IOOption] into an `IO<Option<A>>`.
  RIO<R, Option<A>> get option => matchSync(
        (a) => const Option.none(),
        Option.of,
      );
}

extension ZIOIterableExt<R, E, A> on Iterable<ZIO<R, E, A>> {
  /// Alias for [ZIO.collect]
  ZIO<R, E, IList<A>> get collect => ZIO.collect(this);

  /// Alias for [ZIO.collectDiscard]
  ZIO<R, E, Unit> get collectDiscard => ZIO.collectDiscard(this);

  /// Alias for [ZIO.collectPar]
  ZIO<R, E, IList<A>> get collectPar => ZIO.collectPar(this);

  /// Alias for [ZIO.collectParDiscard]
  ZIO<R, E, Unit> get collectParDiscard => ZIO.collectParDiscard(this);

  /// Alias for [ZIO.raceAll]
  ZIO<R, E, A> get raceAll => ZIO.raceAll(this);
}

extension ZIOEitherExt<E, A> on Either<E, A> {
  /// Alias for [ZIO.fromEither]
  ZIO<NoEnv, E, A> get toZIO => ZIO.fromEither(this);
}

extension ZIOOptionExt<A> on Option<A> {
  /// Alias for [ZIO.fromOption]
  IOOption<A> get toZIO => ZIO.fromOption(this);

  /// Alias for [ZIO.fromOptionOrFail]
  ZIO<NoEnv, E, A> toZIOOrFail<E>(E Function() onNone) =>
      ZIO.fromOptionOrFail(this, onNone);
}

extension ZIOForkExt<R, E, A> on ZIO<R, E, A> {
  /// Fork this [ZIO] into a [Fiber], running it in the background.
  ZIO<R, E2, Fiber<R, E, A>> fork<E2>() => ZIO.from((ctx) {
        final fiber = _DeferredFiber(this);
        return fiber.run<E2>().unsafeRun(ctx).then((_) => Exit.right(fiber));
      });

  /// An [IO] version of [fork].
  RIO<R, Fiber<R, E, A>> get forkIO => fork();

  /// Fork this [ZIO] into a [Fiber], running it in the background.
  ///
  /// When the scope closes, the fiber will be interrupted.
  ZIO<Scope<R>, E2, Fiber<R, E, A>> forkScope<E2>() =>
      fork<E2>().acquireRelease((_) => _.interruptIO);

  /// An [IO] version of [fork].
  RIO<Scope<R>, Fiber<R, E, A>> get forkScopeIO => forkScope();
}
