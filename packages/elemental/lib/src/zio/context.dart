part of '../zio.dart';

/// Represents the context in which a [ZIO] is executed.
class ZIOContext<R> {
  ZIOContext._({
    required this.runtime,
    required this.env,
    required this.signal,
    required this.layers,
  });

  /// Represents the context in which a [ZIO] is executed.
  factory ZIOContext({
    required Runtime runtime,
    required R env,
    required DeferredIO<Unit> signal,
  }) =>
      ZIOContext._(
        runtime: runtime,
        env: env,
        signal: signal,
        layers: LayerContext(),
      );

  final Runtime runtime;
  final R env;
  final DeferredIO<Unit> signal;

  ZIOContext<R2> withEnv<R2>(R2 env) => ZIOContext._(
        runtime: runtime,
        env: env,
        signal: signal,
        layers: layers,
      );

  ZIOContext<NoEnv> get noEnv => withEnv(const NoEnv());

  ZIOContext<R> withRuntime(Runtime runtime) => ZIOContext._(
        runtime: runtime,
        env: env,
        signal: signal,
        layers: layers,
      );

  ZIOContext<R> withSignal(DeferredIO<Unit> signal) => ZIOContext._(
        runtime: runtime,
        env: env,
        signal: signal,
        layers: layers,
      );

  ZIOContext<R> get withoutSignal => withSignal(Deferred());

  // == disposal

  ZIO<R2, E, Unit> close<R2, E>() => layers.close();

  // == layers
  late final LayerContext layers;

  ZIO<R, E, A> accessLayer<E, A>(Layer<E, A> layer) => ZIO.from((ctx) {
        if (layers._unsafeHas(layer)) {
          // ignore: null_check_on_nullable_type_parameter
          return Exit.right(layers._unsafeAccess(layer)!);
        } else if (runtime._layers._unsafeHas(layer)) {
          // ignore: null_check_on_nullable_type_parameter
          return Exit.right(runtime._layers._unsafeAccess(layer)!);
        }

        return layers.provide(layer)._run(ctx);
      });

  ZIO<R, E, S> provideLayer<E, S>(Layer<E, S> layer) => layers.provide(layer);

  ZIO<R, E, Unit> provideService<E, A>(Layer<dynamic, A> layer, A service) =>
      ZIO(() {
        layers._unsafeAddService(layer, service);
        return unit;
      });

  ZIOContext<R> _mergeLayerContext(LayerContext layerContext) => ZIOContext._(
        runtime: runtime,
        env: env,
        signal: signal,
        layers: layerContext._unsafeMerge(layerContext),
      );

  ZIOContext<R> _withLayerContext(LayerContext layerContext) => ZIOContext._(
        runtime: runtime,
        env: env,
        signal: signal,
        layers: layerContext,
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
