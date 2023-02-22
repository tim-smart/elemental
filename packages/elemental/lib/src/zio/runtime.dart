part of '../zio.dart';

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
    try {
      return zio._run(
        const NoEnv(),
        registry,
        interruptionSignal ?? _defaultSignal,
      );
    } catch (error, stack) {
      return Either.left(Defect(error, stack));
    }
  }

  Future<A> runFutureOrThrow<E, A>(
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

  Future<Exit<E, A>> runFuture<E, A>(
    EIO<E, A> zio, {
    Deferred<Unit>? interruptionSignal,
  }) {
    assert(!_disposed, 'Runtime has been disposed');
    return Future.value(run(zio, interruptionSignal: interruptionSignal));
  }

  FutureOr<A> runOrThrow<E, A>(
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

  /// Try to run the ZIO synchronously, throwing a [Future] if it is asynchronous.
  Exit<E, A> runSync<E, A>(
    EIO<E, A> zio, {
    Deferred<Unit>? interruptionSignal,
  }) {
    assert(!_disposed, 'Runtime has been disposed');
    final result = run(zio, interruptionSignal: interruptionSignal);
    if (result is Future) {
      throw result;
    }
    return result;
  }

  /// Try to run the ZIO synchronously, throwing a [Future] if it is asynchronous.
  A runSyncOrThrow<E, A>(EIO<E, A> zio) {
    assert(!_disposed, 'Runtime has been disposed');

    final signal = Deferred<Unit>();
    final exit = run(zio, interruptionSignal: signal);

    if (exit is Future) {
      signal.complete(unit).runSyncOrThrow();
      throw Interrupted<E>();
    }

    return exit.getOrElse((l) => throw l);
  }
}

extension ZIOAtomRegistryExt on AtomRegistry {
  Runtime get zioRuntime => Runtime(this);
}
