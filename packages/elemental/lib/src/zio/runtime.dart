part of '../zio.dart';

abstract class Cause<E> {
  const Cause();
}

class Failure<E> extends Cause<E> {
  const Failure(this.error);
  final E error;
}

class Defect<E> extends Cause<E> {
  const Defect(this.error, this.stackTrace);
  final dynamic error;
  final StackTrace stackTrace;
}

class Interrupted<E> extends Cause<E> {
  const Interrupted();
}

typedef Exit<E, A> = Either<Cause<E>, A>;

class Runtime {
  Runtime._(this.registry);

  factory Runtime(AtomRegistry registry) =>
      _runtimes.putIfAbsent(registry, () => Runtime._(registry));

  static final _runtimes = <AtomRegistry, Runtime>{};

  static EIO<dynamic, Runtime> withLayers(
    Iterable<Layer> layers, {
    Logger? logger,
    LogLevel? logLevel,
    AtomRegistry? registry,
  }) {
    final runtime = Runtime(registry ?? AtomRegistry());

    return ZIO
        .collectPar([
          if (logger != null) loggerLayer.replace(ZIO.succeed(logger)),
          if (logLevel != null) logLevelLayer.replace(ZIO.succeed(logLevel)),
          ...layers,
        ].map((layer) => layer.getOrBuild))
        .withRuntime(runtime)
        .as(runtime);
  }

  static var defaultRuntime = Runtime(AtomRegistry());

  final AtomRegistry registry;
  bool _disposed = false;
  bool get disposed => _disposed;

  static final _defaultSignal = Deferred<Unit>();

  IO<Unit> get dispose => IO(() => _disposed = true)
      .zipRight(registry.get(_layerScopeAtom).closeScope);

  EIO<E, Unit> provideLayer<E, A>(Layer<E, A> layer) =>
      layer.getOrBuild.withRuntime(this).asUnit;

  FutureOr<Exit<E, A>> run<E, A>(
    EIO<E, A> zio, {
    Deferred<Unit>? interruptionSignal,
  }) {
    assert(!_disposed, 'Runtime has been disposed');
    final signal = interruptionSignal ?? _defaultSignal;
    return fromThrowable<Either<E, A>, Exit<E, A>>(
      () => zio._run(NoEnv(), registry, signal),
      onSuccess: (_) => _.mapLeft(Failure.new),
      onError: (error, stackTrace) {
        if (error is Interrupted) {
          return Either.left(Interrupted());
        }
        return Either.left(Defect(error, stackTrace));
      },
      interruptionSignal: signal,
    );
  }

  Future<A> runFuture<E, A>(
    EIO<E, A> zio, {
    Deferred<Unit>? interruptionSignal,
  }) {
    assert(!_disposed, 'Runtime has been disposed');
    return Future.value(run(zio, interruptionSignal: interruptionSignal))
        .then((ea) => ea.match(
              (e) => throw e,
              identity,
            ));
  }

  Future<Exit<E, A>> runFutureExit<E, A>(
    EIO<E, A> zio, {
    Deferred<Unit>? interruptionSignal,
  }) {
    assert(!_disposed, 'Runtime has been disposed');
    return Future.value(run(zio, interruptionSignal: interruptionSignal));
  }

  FutureOr<A> runFutureOr<E, A>(
    EIO<E, A> zio, {
    Deferred<Unit>? interruptionSignal,
  }) {
    assert(!_disposed, 'Runtime has been disposed');
    return run(zio, interruptionSignal: interruptionSignal).flatMapFOr(
      (ea) => ea.match(
        (e) => throw e,
        identity,
      ),
      interruptionSignal: _defaultSignal,
    );
  }

  Exit<E, A> runSyncExit<E, A>(EIO<E, A> zio) {
    assert(!_disposed, 'Runtime has been disposed');
    final signal = Deferred<Unit>();
    final result = run(zio, interruptionSignal: signal);
    if (result is Future) {
      signal.complete(unit).runSyncExit();
      throw Interrupted();
    }
    return result;
  }

  A runSync<A>(IO<A> zio) {
    assert(!_disposed, 'Runtime has been disposed');
    return runSyncExit(zio).toNullable()!;
  }
}

extension ZIOAtomRegistryExt on AtomRegistry {
  Runtime get zioRuntime => Runtime(this);
}
