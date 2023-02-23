part of '../zio.dart';

class Layer<E, Service> {
  Layer._({
    required ZIO<Scope, E, Service> make,
    bool scoped = false,
    bool memoized = true,
    Symbol? tag,
  })  : tag = tag ?? Symbol("Layer<$E, $Service>()"),
        _make = make,
        _scoped = scoped,
        _memoized = memoized;

  /// A [Layer] constructs a service, and is only built once per [ZIO]
  /// execution.
  factory Layer(EIO<E, Service> make) => Layer._(make: make.lift());

  /// A [Layer] that has scoped resources.
  factory Layer.scoped(ZIO<Scope, E, Service> make) =>
      Layer._(make: make, scoped: true);

  /// A [Layer] that is discarded after each use.
  factory Layer.autoDispose(EIO<E, Service> make) =>
      Layer._(make: make.lift(), memoized: false);

  /// A [Layer] that is discarded after each use, and has scoped resources.
  factory Layer.autoDisposeScope(ZIO<Scope, E, Service> make) {
    return Layer._(make: make, memoized: false, scoped: true);
  }

  // ignore: prefer_const_constructors
  final Symbol tag;

  final ZIO<Scope, E, Service> _make;
  final bool _memoized;
  final bool _scoped;

  EIO<E, Service> get access => ZIO.layer(this);

  EIO<E, A> accessWith<A>(A Function(Service _) f) => access.map(f);

  ZIO<R, E, A> accessWithZIO<R, A>(ZIO<R, E, A> Function(Service _) f) =>
      ZIO<R, E, Service>.layer(this).flatMap(f);

  Layer<E2, Service> replace<E2>(EIO<E2, Service> build) => Layer._(
        tag: tag,
        make: build.lift(),
        scoped: _scoped,
        memoized: _memoized,
      );

  Layer<E2, Service> replaceScoped<E2>(ZIO<Scope, E2, Service> build) =>
      Layer._(
        tag: tag,
        make: build,
        scoped: _scoped,
        memoized: _memoized,
      );

  @override
  String toString() =>
      'Layer<$E, $Service>(scoped: $_scoped, memoized: $_memoized)';
}

class _LayerContext {
  _LayerContext(this._registerScope);

  final void Function(ScopeMixin scope) _registerScope;
  final layers = HashMap<Symbol, EIO<dynamic, dynamic>>();

  ZIO<R, E, A> access<R, E, A>(Layer<E, A> layer) {
    final build = layers.putIfAbsent(layer.tag, () {
      final scope = Scope.closable();
      final build = layer._make.provide(scope).memoize.runSyncOrThrow();

      if (layer._scoped) {
        _registerScope(scope);
      }

      return build;
    }) as EIO<E, A>;

    return build.lift();
  }

  void unsafeProvide(Layer layer) {
    layers.remove(layer.tag);
    access(layer);
  }

  bool unsafeHas(Layer layer) => layers.containsKey(layer.tag);
}
