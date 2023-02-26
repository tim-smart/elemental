part of '../zio.dart';

class Runtime {
  Runtime() : _layers = LayerContext();
  Runtime.withLayerContext(this._layers);

  static EIO<dynamic, Runtime> withLayers(
    Iterable<Layer> layers, {
    Logger? logger,
    LogLevel? logLevel,
  }) {
    final runtime = Runtime();

    if (logger != null) runtime.provideService(loggerLayer)(logger);
    if (logLevel != null) runtime.provideService(logLevelLayer)(logLevel);

    return runtime.provideLayers(layers).as(runtime).withRuntime(runtime);
  }

  // == defaults

  static var defaultRuntime = Runtime();
  static final _defaultSignal = DeferredIO<Unit>();

  // == layers

  final LayerContext _layers;

  EIO<E, S> provideLayer<E, S>(Layer<E, S> layer) => ZIO.from(
        (ctx) => _layers.provide(layer)._run(ctx._withLayerContext(_layers)),
      );

  IO<Unit> provideLayerLazy(Layer layer) => ZIO.from(
        (ctx) => _layers
            .provideLazy<NoEnv, Never>(layer)
            ._run(ctx._withLayerContext(_layers)),
      );

  EIO<dynamic, Unit> provideLayers(Iterable<Layer> layers) =>
      layers.map(provideLayer).collectDiscard;

  IO<Unit> provideLayersLazy(Iterable<Layer> layers) =>
      layers.map(provideLayerLazy).collectDiscard;

  IO<Unit> Function(S service) provideService<S>(Layer<dynamic, S> layer) =>
      (service) => ZIO(() {
            _layers._unsafeAddService(layer, service);
            return unit;
          });

  Runtime mergeLayerContext(LayerContext layerContext) =>
      Runtime.withLayerContext(_layers.merge(layerContext));

  // == disposal

  bool _disposed = false;
  bool get disposed => _disposed;
  IO<Unit> get dispose => IO(() => _disposed = true).zipRight(_layers.close());

  // == running zios

  FutureOr<Exit<E, A>> run<E, A>(
    EIO<E, A> zio, {
    DeferredIO<Unit>? interruptionSignal,
  }) {
    assert(!_disposed, 'Runtime has been disposed');

    final context = ZIOContext(
      runtime: this,
      env: const NoEnv(),
      signal: interruptionSignal ?? _defaultSignal,
    );

    try {
      return zio.alwaysIgnore(context.close())._run(context);
    } catch (error, stack) {
      return Either.left(Defect(error, stack));
    }
  }

  Future<A> runFutureOrThrow<E, A>(
    EIO<E, A> zio, {
    DeferredIO<Unit>? interruptionSignal,
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
    DeferredIO<Unit>? interruptionSignal,
  }) {
    assert(!_disposed, 'Runtime has been disposed');
    return Future.value(run(zio, interruptionSignal: interruptionSignal));
  }

  FutureOr<A> runOrThrow<E, A>(
    EIO<E, A> zio, {
    DeferredIO<Unit>? interruptionSignal,
  }) {
    assert(!_disposed, 'Runtime has been disposed');
    return run(zio, interruptionSignal: interruptionSignal).then(
      (ea) => ea.match(
        (e) => throw e,
        identity,
      ),
    );
  }

  /// Try to run the ZIO synchronously, throwing a [Future] if it is asynchronous.
  Exit<E, A> runSync<E, A>(
    EIO<E, A> zio, {
    DeferredIO<Unit>? interruptionSignal,
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

    final signal = DeferredIO<Unit>();
    final exit = run(zio, interruptionSignal: signal);

    if (exit is Future) {
      signal.completeIO(unit).runSyncOrThrow();
      throw Interrupted<E>();
    }

    return exit.getOrElse((l) => throw l);
  }
}
