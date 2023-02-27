part of '../zio.dart';

/// A [Layer] can be used to construct a service.
///
/// It will only be built once per [ZIO] execution, or it can be provided to
/// a [Runtime] using [Runtime.provideLayer].
///
/// If it is provided to a [Runtime], it will be built once per [Runtime] - being
/// reused for all [ZIO] executions.
///
/// It can be accessed using [access] or [accessWith]. Or by calling [ZIO.layer].
///
/// You can also replace a [Layer] using [Layer.replace].
class Layer<E, Service> {
  Layer._({
    required ZIO<Scope<NoEnv>, E, Service> make,
    Symbol? tag,
  })  : tag = tag ?? Symbol("Layer<$E, $Service>()"),
        _make = make;

  /// A [Layer] constructs a service, and is only built once per [ZIO]
  /// execution.
  factory Layer(EIO<E, Service> make) => Layer._(make: make.lift());

  /// A [Layer] that has scoped resources.
  factory Layer.scoped(ZIO<Scope<NoEnv>, E, Service> make) =>
      Layer._(make: make);

  // ignore: prefer_const_constructors
  final Symbol tag;

  final ZIO<Scope<NoEnv>, E, Service> _make;

  EIO<E, Service> get access => ZIO.layer(this);

  EIO<E, A> accessWith<A>(A Function(Service _) f) => access.map(f);

  ZIO<R, E, A> accessWithZIO<R, A>(ZIO<R, E, A> Function(Service _) f) =>
      ZIO<R, E, Service>.layer(this).flatMap(f);

  Layer<E2, Service> mapError<E2>(E2 Function(E _) f) => Layer._(
        tag: tag,
        make: _make.mapError(f),
      );

  Layer<E, Service> provideLayer(Layer<E, dynamic> layer) => Layer._(
        tag: tag,
        make: _make.provideLayer(layer),
      );

  Layer<E2, Service> replace<E2>(EIO<E2, Service> build) => Layer._(
        tag: tag,
        make: build.lift(),
      );

  Layer<E2, Service> replaceScoped<E2>(ZIO<Scope<NoEnv>, E2, Service> build) =>
      Layer._(
        tag: tag,
        make: build,
      );

  EIO<E, LayerContext> get buildContext => ZIO.from((ctx) {
        final context = LayerContext();
        return context.provide<NoEnv, E, Service>(this).as(context)._run(ctx);
      });

  ZIO<Scope<NoEnv>, E, Service> get build => ZIO.from((ctx) {
        final context = LayerContext();
        return context
            .provide<NoEnv, E, Service>(this)
            .addFinalizer(context.close())
            ._run(ctx);
      });

  late final atomSyncOnly = ReadOnlyAtom<Service>((get) {
    final runtime = get(runtimeAtom);

    final context = LayerContext();
    get.onDispose(
      () => context.close<NoEnv, Never>().run(runtime: runtime),
    );

    try {
      context.provide<NoEnv, E, Service>(this).runSyncOrThrow(runtime);
    } catch (err) {
      throw "Could not build layer, probably due to asynchronous build. Error: $err";
    }

    return context._unsafeAccess(this)!;
  });

  late final atom = futureAtom<Service>((get) {
    final runtime = get(runtimeAtom);

    final context = LayerContext();
    get.onDispose(
      () => context.close<NoEnv, Never>().run(runtime: runtime),
    );

    return context
        .provide<NoEnv, E, Service>(this)
        .runFutureOrThrow(runtime: runtime);
  });

  @override
  String toString() => 'Layer<$E, $Service>()';
}

class LayerContext {
  LayerContext()
      : _services = HashMap(),
        _cache = HashMap(),
        _lazy = HashSet();

  LayerContext.populated(this._services, this._cache, this._lazy);

  final _scope = Scope.closable();
  final HashMap<Symbol, dynamic> _services;
  final HashMap<Layer, EIO<dynamic, dynamic>> _cache;
  final HashSet<Symbol> _lazy;

  ZIO<R, E, S> provide<R, E, S>(Layer<E, S> layer) => EIO<E, S>.from((ctx) {
        if (_cache.containsKey(layer)) {
          return (_cache[layer] as EIO<E, S>)._run(ctx);
        }

        final build = layer._make.provide(_scope).memoize.runSyncOrThrow();
        _cache[layer] = build;
        return build._run(ctx._withLayerContext(this));
      }) //
          .lift<R>()
          .tap((_) => ZIO(() {
                _services[layer.tag] = _;
              }));

  ZIO<R, E, Unit> provideLazy<R, E>(Layer layer) => ZIO(() {
        _lazy.add(layer.tag);
        return unit;
      });

  ZIO<R, E, Unit> Function(S service) provideService<R, E, S>(
    Layer<dynamic, S> layer,
  ) =>
      (service) => ZIO(() {
            _unsafeAddService(layer, service);
            return unit;
          });

  ZIO<R, E, Unit> close<R, E>() => ZIO<R, E, void>(() {
        _services.clear();
        _cache.clear();
      }).zipRight(_scope.closeScope());

  ZIO<R, E, A> use<R, E, A>(ZIO<R, E, A> zio) => zio.provideLayerContext(this);

  LayerContext merge(LayerContext other) => LayerContext.populated(
        HashMap.from(_services)..addAll(other._services),
        HashMap.from(_cache)..addAll(other._cache),
        HashSet.from(_lazy)..addAll(other._lazy),
      );

  // === Unsafe ===

  void _unsafeAddService<A>(Layer<dynamic, A> layer, A service) {
    _services[layer.tag] = service;
  }

  LayerContext _unsafeMerge(LayerContext other) {
    _services.addAll(other._services);
    _cache.addAll(other._cache);
    return this;
  }

  A? _unsafeAccess<A>(Layer<dynamic, A> layer) => _services[layer.tag];
  bool _unsafeHas(Layer layer) => _services.containsKey(layer.tag);
  bool _unsafeHasLazy(Layer layer) => _lazy.contains(layer.tag);
}
