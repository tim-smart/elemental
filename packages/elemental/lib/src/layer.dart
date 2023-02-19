import 'package:elemental/elemental.dart';
// ignore: implementation_imports
import 'package:nucleus/src/internal/internal.dart';

typedef GetLayer = EIO<E, A> Function<E, A>(Layer<E, A> layer);

final _layerScopeAtom = atom((get) => Scope.closable());

class Layer<E, Service> {
  Layer._(this._make);

  factory Layer(
    EIO<E, Service> Function(GetAtom get, GetLayer getLayer) make,
  ) =>
      Layer._((get, getLayer) => make(get, getLayer).lift());

  factory Layer.scoped(
    ZIO<Scope, E, Service> Function(GetAtom get, GetLayer getLayer) make,
  ) =>
      Layer._(make);

  final ZIO<Scope, E, Service> Function(GetAtom get, GetLayer getLayer) _make;

  late final Atom<Service> atom = ReadOnlyAtom(
    (get) => get(_stateAtom).match(
      () => throw StateError('Layer not built'),
      identity,
    ),
  ).keepAlive();

  final _stateAtom = StateAtom(Option<Service>.none()).keepAlive();

  late final Atom<EIO<E, Service>> _buildAtom = ReadOnlyAtom((get) {
    EIO<LE, A> getLayer<LE, A>(Layer<LE, A> layer) =>
        get.once(layer._stateAtom).match(
              () => get.once(layer._buildAtom),
              (service) => ZIO.succeed(service),
            );

    return _make(get.once, getLayer)
        .tap((service) => IO(() {
              get.set(_stateAtom, Option.of(service));
            }).lift())
        .provide(get.once(_layerScopeAtom))
        .memoize
        .runSync();
  });

  static EIO<dynamic, Unit> buildAllWith(
    AtomRegistry registry,
    Iterable<Layer> layers,
  ) =>
      ZIO
          .collectPar(
            layers.map((layer) => registry.get(layer._buildAtom)),
          )
          .asUnit;

  static EIO<dynamic, AtomRegistry> buildAll(
    Iterable<Layer> layers, {
    List<AtomInitialValue> initialValues = const [],
    Scheduler? scheduler,
  }) {
    final registry = AtomRegistry(
      scheduler: scheduler,
      initialValues: initialValues,
    );
    return buildAllWith(registry, layers).as(registry);
  }

  static IO<Unit> closeAll(GetAtom get) => get(_layerScopeAtom).closeScope;
}
