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
    required ZIO<Scope, E, Service> make,
    bool scoped = false,
    bool memoized = true,
    Symbol? tag,
  })  : tag = tag ?? Symbol("Layer<$E, $Service>()"),
        _make = make,
        _scoped = scoped;

  /// A [Layer] constructs a service, and is only built once per [ZIO]
  /// execution.
  factory Layer(EIO<E, Service> make) => Layer._(make: make.lift());

  /// A [Layer] that has scoped resources.
  factory Layer.scoped(ZIO<Scope, E, Service> make) =>
      Layer._(make: make, scoped: true);

  // ignore: prefer_const_constructors
  final Symbol tag;

  final ZIO<Scope, E, Service> _make;
  final bool _scoped;

  EIO<E, Service> get access => ZIO.layer(this);

  EIO<E, A> accessWith<A>(A Function(Service _) f) => access.map(f);

  ZIO<R, E, A> accessWithZIO<R, A>(ZIO<R, E, A> Function(Service _) f) =>
      ZIO<R, E, Service>.layer(this).flatMap(f);

  Layer<E2, Service> mapError<E2>(E2 Function(E _) f) => Layer._(
        tag: tag,
        make: _make.mapError(f),
        scoped: _scoped,
      );

  Layer<E, Service> provideLayer(Layer<E, dynamic> layer) => Layer._(
        tag: tag,
        make: _make.provideLayer(layer),
        scoped: _scoped,
      );

  Layer<E2, Service> replace<E2>(EIO<E2, Service> build) => Layer._(
        tag: tag,
        make: build.lift(),
        scoped: false,
      );

  Layer<E2, Service> replaceScoped<E2>(ZIO<Scope, E2, Service> build) =>
      Layer._(
        tag: tag,
        make: build,
        scoped: true,
      );

  ReadOnlyAtom<Service> get atomSyncOnly => ReadOnlyAtom((get) {
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

  FutureAtom<Service> get atom => futureAtom((get) {
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
  String toString() => 'Layer<$E, $Service>(scoped: $_scoped)';
}

class LayerContext {
  LayerContext();

  final _scope = Scope.closable();
  final _services = HashMap<Symbol, dynamic>();
  final _cache = HashMap<Layer, EIO<dynamic, dynamic>>();

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

  ZIO<R, E, Unit> Function(S service) provideService<R, E, S>(
    Layer<dynamic, S> layer,
  ) =>
      (service) => ZIO(() {
            _unsafeAddService(layer, service);
            return unit;
          });

  ZIO<R, E, Unit> close<R, E>() => _scope.closeScope();

  ZIO<R, E, A> use<R, E, A>(ZIO<R, E, A> zio) => zio.provideLayerContext(this);

  // === Unsafe ===

  void _unsafeAddService<A>(Layer<dynamic, A> layer, A service) {
    _services[layer.tag] = service;
  }

  LayerContext _unsafeMerge(LayerContext other) {
    _services.addAll(other._services);
    return this;
  }

  A? _unsafeAccess<A>(Layer<dynamic, A> layer) => _services[layer.tag];
  bool _unsafeHas(Layer layer) => _services.containsKey(layer.tag);
}
