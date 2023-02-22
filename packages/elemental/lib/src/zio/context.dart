part of '../zio.dart';

class ZIOContext<R> {
  ZIOContext._({
    required this.runtime,
    required this.env,
    required this.signal,
    this.scopes = const [],
    _LayerContext? layerContext,
  }) {
    _layers = layerContext ?? _LayerContext(unsafeAddScope);
  }

  factory ZIOContext({
    required Runtime runtime,
    required R env,
    required Deferred<Unit> signal,
  }) =>
      ZIOContext._(runtime: runtime, env: env, signal: signal);

  final Runtime runtime;
  final R env;
  final Deferred<Unit> signal;

  ZIOContext<R2> withEnv<R2>(R2 env) => ZIOContext._(
        runtime: runtime,
        env: env,
        signal: signal,
        scopes: scopes,
        layerContext: _layers,
      );

  ZIOContext<NoEnv> get asNoEnv => withEnv(const NoEnv());

  ZIOContext<R> withRuntime(Runtime runtime) => ZIOContext._(
        runtime: runtime,
        env: env,
        signal: signal,
        scopes: scopes,
        layerContext: _layers,
      );

  ZIOContext<R> get withoutSignal => ZIOContext._(
        runtime: runtime,
        env: env,
        signal: Deferred(),
        scopes: scopes,
        layerContext: _layers,
      );

  // == scopes

  final List<ScopeMixin> scopes;

  IO<Unit> addScope(ScopeMixin scope) => IO(() {
        unsafeAddScope(scope);
        return unit;
      });

  void unsafeAddScope(ScopeMixin scope) => scopes.add(scope);

  ZIO<R2, E, Unit> close<R2, E>() => scopes.isEmpty
      ? ZIO.unit()
      : scopes.map((s) => s.closeScope<R2, E>()).collectParDiscard;

  // == layers
  late final _LayerContext _layers;

  ZIO<R2, E, A> accessLayer<R2, E, A>(Layer<E, A> layer) {
    if (layer._memoized) {
      return runtime._layers.access(layer);
    }

    return _layers.access(layer);
  }
}
