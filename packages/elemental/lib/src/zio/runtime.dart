part of '../zio.dart';

class Runtime {
  Runtime._(this.registry);

  factory Runtime(AtomRegistry registry) =>
      _runtimes.putIfAbsent(registry, () => Runtime._(registry));

  static final _runtimes = <AtomRegistry, Runtime>{};

  static EIO<dynamic, Runtime> withLayers(
    Iterable<Layer> layers, {
    List<AtomInitialValue> initialValues = const [],
    Scheduler? scheduler,
  }) {
    final registry = AtomRegistry(
      scheduler: scheduler,
      initialValues: initialValues,
    );
    final runtime = Runtime(registry);

    return ZIO
        .collectPar(layers.map((layer) => layer.getOrBuild))
        .withRuntime(runtime)
        .as(runtime);
  }

  static var defaultRuntime = Runtime(AtomRegistry());

  final AtomRegistry registry;
  bool _disposed = false;
  bool get disposed => _disposed;

  IO<Unit> get dispose => IO(() => _disposed = true)
      .zipRight(registry.get(_layerScopeAtom).closeScope);

  IO<Unit> withLogger(Logger logger) => loggerLayer.replace(IO.succeed(logger));

  IO<Unit> withLogLevel(LogLevel level) =>
      logLevelLayer.replace(IO.succeed(level));

  FutureOr<Either<E, A>> run<E, A>(EIO<E, A> zio) {
    assert(!_disposed, 'Runtime has been disposed');
    return zio._run(NoEnv(), registry);
  }

  Future<A> runFuture<E, A>(EIO<E, A> zio) {
    assert(!_disposed, 'Runtime has been disposed');
    return Future.value(run(zio)).then((ea) => ea.match(
          (e) => throw e as Object,
          identity,
        ));
  }

  Future<Either<E, A>> runFutureEither<E, A>(EIO<E, A> zio) {
    assert(!_disposed, 'Runtime has been disposed');
    return Future.value(run(zio));
  }

  FutureOr<A> runFutureOr<E, A>(EIO<E, A> zio) {
    assert(!_disposed, 'Runtime has been disposed');
    return run(zio).flatMapFOr((ea) => ea.match(
          (e) => throw e as Object,
          identity,
        ));
  }

  Either<E, A> runSyncEither<E, A>(EIO<E, A> zio) {
    assert(!_disposed, 'Runtime has been disposed');
    final result = run(zio);
    if (result is Future) {
      throw result;
    }
    return result;
  }

  A runSync<A>(IO<A> zio) {
    assert(!_disposed, 'Runtime has been disposed');
    return runSyncEither(zio).toNullable()!;
  }
}

extension ZIOAtomRegistryExt on AtomRegistry {
  Runtime get zioRuntime => Runtime(this);
}
