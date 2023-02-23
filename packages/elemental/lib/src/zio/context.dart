part of '../zio.dart';

class ZIOContext<R> {
  ZIOContext._({
    required this.runtime,
    required this.env,
    required this.signal,
    List<ScopeMixin>? scopes,
    _LayerContext? layerContext,
  }) : _scopes = scopes ?? [] {
    _layers = layerContext ?? _LayerContext(unsafeAddScope);
  }

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
        scopes: _scopes,
        layerContext: _layers,
      );

  ZIOContext<NoEnv> get noEnv => withEnv(const NoEnv());

  ZIOContext<R> withRuntime(Runtime runtime) => ZIOContext._(
        runtime: runtime,
        env: env,
        signal: signal,
        scopes: _scopes,
        layerContext: _layers,
      );

  ZIOContext<R> get withoutSignal => ZIOContext._(
        runtime: runtime,
        env: env,
        signal: Deferred(),
        scopes: _scopes,
        layerContext: _layers,
      );

  // == scopes

  final List<ScopeMixin> _scopes;

  IO<Unit> addScope(ScopeMixin scope) => IO(() {
        unsafeAddScope(scope);
        return unit;
      });

  void unsafeAddScope(ScopeMixin scope) => _scopes.add(scope);

  ZIO<R2, E, Unit> close<R2, E>() => ZIO.from(
        (ctx) => _scopes.isEmpty
            ? Exit.right(unit)
            : _scopes
                .map((s) => s.closeScope<R2, E>())
                .collectParDiscard
                ._run(ctx),
      );

  // == layers
  late final _LayerContext _layers;

  ZIO<R, E, A> accessLayer<E, A>(Layer<E, A> layer) => ZIO.from((ctx) {
        if (_layers.unsafeHas(layer)) {
          // ignore: null_check_on_nullable_type_parameter
          return Exit.right(_layers.unsafeAccess(layer)!);
        } else if (runtime._layers.unsafeHas(layer)) {
          // ignore: null_check_on_nullable_type_parameter
          return Exit.right(runtime._layers.unsafeAccess(layer)!);
        }

        return _layers.provide(layer)._run(ctx);
      });

  ZIO<R, E, S> provideLayer<E, S>(Layer<E, S> layer) => _layers.provide(layer);

  ZIO<R, E, Unit> provideService<E, A>(Layer<dynamic, A> layer, A service) =>
      ZIO(() {
        _layers.unsafeAddService(layer, service);
        return unit;
      });

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
