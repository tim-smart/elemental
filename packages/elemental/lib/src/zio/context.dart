part of '../zio.dart';

/// Represents the context in which a [ZIO] is executed.
class ZIOContext<R> {
  ZIOContext._({
    required this.runtime,
    required this.env,
    required this.signal,
    required this.layers,
    required IMap<Symbol, IMap<String, dynamic>> annotations,
  }) : _annotations = annotations;

  /// Represents the context in which a [ZIO] is executed.
  factory ZIOContext({
    required Runtime runtime,
    required R env,
    required DeferredIO<Never> signal,
  }) =>
      ZIOContext._(
        runtime: runtime,
        env: env,
        signal: signal,
        layers: LayerContext(),
        annotations: const IMapConst({}),
      );

  final Runtime runtime;
  final R env;
  final DeferredIO<Never> signal;

  ZIOContext<R2> withEnv<R2>(R2 env) => ZIOContext._(
        runtime: runtime,
        env: env,
        signal: signal,
        layers: layers,
        annotations: _annotations,
      );

  ZIOContext<NoEnv> get noEnv => withEnv(const NoEnv());

  ZIOContext<R> withRuntime(Runtime runtime) => copyWith(runtime: runtime);

  ZIOContext<R> withSignal(DeferredIO<Never> signal) =>
      copyWith(signal: signal);

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
        } else if (runtime._layers._unsafeHasLazy(layer)) {
          return runtime._layers.provide(layer).unsafeRun(ctx);
        }

        return layers.provide(layer).unsafeRun(ctx);
      });

  ZIO<R, E, S> provideLayer<E, S>(Layer<E, S> layer) => layers.provide(layer);

  ZIO<R, E, Unit> provideService<E, A>(Layer<dynamic, A> layer, A service) =>
      ZIO(() {
        layers._unsafeAddService(layer, service);
        return unit;
      });

  ZIOContext<R> _mergeLayerContext(LayerContext layerContext) => copyWith(
        layers: layerContext._unsafeMerge(layerContext),
      );

  ZIOContext<R> _withLayerContext(LayerContext layerContext) =>
      copyWith(layers: layerContext);

  // == annotations
  final IMap<Symbol, IMap<String, dynamic>> _annotations;

  ZIOContext<R> unsafeAnnotate(
    Symbol key,
    String name,
    dynamic value,
  ) =>
      copyWith(
        annotations: _annotations.update(
          key,
          (_) => _.add(name, value),
          ifAbsent: () => IMap<String, dynamic>().add(name, value),
        ),
      );

  IMap<String, dynamic> unsafeGetAnnotations(Symbol key) =>
      _annotations[key] ?? const IMapConst({});

  ZIOContext<R> copyWith({
    Runtime? runtime,
    R? env,
    DeferredIO<Never>? signal,
    LayerContext? layers,
    IMap<Symbol, IMap<String, dynamic>>? annotations,
  }) =>
      ZIOContext._(
        runtime: runtime ?? this.runtime,
        env: env ?? this.env,
        signal: signal ?? this.signal,
        layers: layers ?? this.layers,
        annotations: annotations ?? this._annotations,
      );
}
