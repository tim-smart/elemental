part of '../zio.dart';

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
        scoped: _scoped,
      );

  Layer<E2, Service> replaceScoped<E2>(ZIO<Scope, E2, Service> build) =>
      Layer._(
        tag: tag,
        make: build,
        scoped: _scoped,
      );

  @override
  String toString() => 'Layer<$E, $Service>(scoped: $_scoped)';
}

class _LayerContext {
  _LayerContext(this._registerScope);

  final void Function(ScopeMixin scope) _registerScope;
  final _services = HashMap<Symbol, dynamic>();
  final _cache = HashMap<Layer, EIO<dynamic, dynamic>>();

  ZIO<R, E, S> provide<R, E, S>(Layer<E, S> layer) => EIO<E, S>.from((ctx) {
        if (_cache.containsKey(layer)) {
          return (_cache[layer] as EIO<E, S>)._run(ctx);
        }

        final build = _build(layer).memoize.runSyncOrThrow();
        _cache[layer] = build;
        return build._run(ctx);
      }) //
          .lift<R>()
          .tap(
            (_) => ZIO(() {
              _services[layer.tag] = _;
            }),
          );

  EIO<E, S> _build<E, S>(Layer<E, S> layer) => EIO<E, EIO<E, S>>(() {
        final scope = Scope.closable();
        if (layer._scoped) {
          _registerScope(scope);
        }
        return layer._make.provide(scope);
      }).flatMap(identity);

  A? unsafeAccess<A>(Layer<dynamic, A> layer) => _services[layer.tag];

  bool unsafeHas(Layer layer) => _services.containsKey(layer.tag);

  void unsafeAddService<A>(Layer<dynamic, A> layer, A service) {
    _services[layer.tag] = service;
  }
}
