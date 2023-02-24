part of '../zio.dart';

/// Represents the context in which a [ZIO] is executed.
class ZIOContext<R> {
  ZIOContext._({
    required this.runtime,
    required this.env,
    required this.signal,
    LayerContext? layerContext,
  }) : _layers = layerContext ?? LayerContext();

  /// Represents the context in which a [ZIO] is executed.
  factory ZIOContext({
    required Runtime runtime,
    required R env,
    required DeferredIO<Unit> signal,
  }) =>
      ZIOContext._(runtime: runtime, env: env, signal: signal);

  final Runtime runtime;
  final R env;
  final DeferredIO<Unit> signal;

  ZIOContext<R2> withEnv<R2>(R2 env) => ZIOContext._(
        runtime: runtime,
        env: env,
        signal: signal,
        layerContext: _layers,
      );

  ZIOContext<NoEnv> get noEnv => withEnv(const NoEnv());

  ZIOContext<R> withRuntime(Runtime runtime) => ZIOContext._(
        runtime: runtime,
        env: env,
        signal: signal,
        layerContext: _layers,
      );

  ZIOContext<R> get withoutSignal => ZIOContext._(
        runtime: runtime,
        env: env,
        signal: Deferred(),
        layerContext: _layers,
      );

  // == scopes

  ZIO<R2, E, Unit> close<R2, E>() =>
      _layers.close<R2, E>().zipRight(signal.complete(unit));

  // == layers
  late final LayerContext _layers;

  ZIO<R, E, A> accessLayer<E, A>(Layer<E, A> layer) => ZIO.from((ctx) {
        if (_layers._unsafeHas(layer)) {
          // ignore: null_check_on_nullable_type_parameter
          return Exit.right(_layers._unsafeAccess(layer)!);
        } else if (runtime._layers._unsafeHas(layer)) {
          // ignore: null_check_on_nullable_type_parameter
          return Exit.right(runtime._layers._unsafeAccess(layer)!);
        }

        return _layers.provide(layer)._run(ctx);
      });

  ZIO<R, E, S> provideLayer<E, S>(Layer<E, S> layer) => _layers.provide(layer);

  ZIO<R, E, Unit> provideService<E, A>(Layer<dynamic, A> layer, A service) =>
      ZIO(() {
        _layers._unsafeAddService(layer, service);
        return unit;
      });

  ZIOContext<R> _mergeLayerContext(LayerContext layerContext) => ZIOContext._(
        runtime: runtime,
        env: env,
        signal: signal,
        layerContext: layerContext._unsafeMerge(layerContext),
      );

  ZIOContext<R> _withLayerContext(LayerContext layerContext) => ZIOContext._(
        runtime: runtime,
        env: env,
        signal: signal,
        layerContext: layerContext,
      );

  // == annotations
  final _annotations = HashMap<Symbol, HashMap<String, dynamic>>();

  void unsafeAnnotate(
    Symbol key,
    String name,
    dynamic value,
  ) {
    final map = _annotations[key] ??= HashMap();
    map[name] = value;
  }

  HashMap<String, dynamic> unsafeGetAnnotations(Symbol key) =>
      _annotations[key] ?? HashMap();

  HashMap<String, dynamic> unsafeGetAndClearAnnotations(Symbol key) {
    final a = _annotations[key] ?? HashMap();
    _annotations.remove(key);
    return a;
  }

  void unsafeClearAnnotations(Symbol key) => _annotations.remove(key);
}
