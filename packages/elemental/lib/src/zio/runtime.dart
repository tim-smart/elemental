part of '../zio.dart';

class Runtime {
  Runtime({
    Logger logger = const Logger(),
    LogLevel logLevel = LogLevel.debug,
  }) {
    _layers.unsafeAddService(logLevelLayer, logLevel);
    _layers.unsafeAddService(loggerLayer, logger);
  }

  static EIO<dynamic, Runtime> withLayers(
    Iterable<Layer> layers, {
    Logger logger = const Logger(),
    LogLevel logLevel = LogLevel.debug,
  }) {
    final runtime = Runtime(logger: logger, logLevel: logLevel);

    return runtime.provideLayers(layers).as(runtime).withRuntime(runtime);
  }

  // == defaults

  static var defaultRuntime = Runtime();
  static final _defaultSignal = Deferred<Unit>();

  // == scopes

  final _scopes = <ScopeMixin>[];

  bool _disposed = false;
  bool get disposed => _disposed;

  IO<Unit> get dispose => IO(() => _disposed = true)
      .zipRight(_scopes.map((s) => s.closeScopeIO).collectParDiscard);

  // == layers

  late final _layers = _LayerContext((scope) => _scopes.add(scope));

  EIO<E, S> provideLayer<E, S>(Layer<E, S> layer) => _layers.provide(layer);

  EIO<dynamic, Unit> provideLayers(Iterable<Layer> layers) =>
      layers.map(provideLayer).collectDiscard;

  IO<Unit> Function(S service) provideService<S>(Layer<dynamic, S> layer) =>
      (service) => ZIO(() {
            _layers.unsafeAddService(layer, service);
            return unit;
          });

  // == running zios

  FutureOr<Exit<E, A>> run<E, A>(
    EIO<E, A> zio, {
    Deferred<Unit>? interruptionSignal,
  }) {
    assert(!_disposed, 'Runtime has been disposed');

    final context = ZIOContext(
      runtime: this,
      env: const NoEnv(),
      signal: interruptionSignal ?? Deferred(),
    );

    try {
      return zio.alwaysIgnore(context.close())._run(context);
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
      signal.completeIO(unit).runSyncOrThrow();
      throw Interrupted<E>();
    }

    return exit.getOrElse((l) => throw l);
  }
}
