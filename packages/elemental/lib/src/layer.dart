import 'package:elemental/elemental.dart';
import 'package:fpdart/fpdart.dart';
import 'package:nucleus/nucleus.dart';
// ignore: implementation_imports
import 'package:nucleus/src/internal/internal.dart';

typedef GetLayer = EIO<E, A> Function<E, A>(Layer<E, A> layer);

final layerScopeAtom = atom((get) => Scope.closable());

class Layer<E, Service> {
  Layer(this._make);

  final ZIO<Scope, E, Service> Function(GetLayer get) _make;

  late final Atom<Service> atom = ReadOnlyAtom(
    (get) => get(_stateAtom).match(
      () => throw StateError('Layer not built'),
      identity,
    ),
  );

  final _stateAtom = StateAtom(Option<Service>.none());

  late final Atom<ZIO<Scope, E, Service>> _buildAtom = ReadOnlyAtom((get) {
    EIO<LE, A> getLayer<LE, A>(Layer<LE, A> layer) =>
        get(layer._stateAtom).match(
          () {
            final layerZIO = get(layer._buildAtom);
            return layerZIO
                .flatMap(
                  (service) => ZIO(() {
                    get.set(layer._stateAtom, Option.of(service));
                    return service;
                  }),
                )
                .provide(get.once(layerScopeAtom));
          },
          (service) => ZIO.succeed(service),
        );

    return _make(getLayer).memoize.runSync();
  });

  static EIO<dynamic, Unit> buildAllWithRegistry(
    AtomRegistry registry,
    Iterable<Layer> layers,
  ) =>
      ZIO
          .collectPar(
            layers.map((layer) => registry.get(layer._buildAtom)),
          )
          .provide(registry.get(layerScopeAtom))
          .asUnit;

  static EIO<dynamic, AtomRegistry> buildRegistry(
    Iterable<Layer> layers, {
    List<AtomInitialValue> initialValues = const [],
    Scheduler? scheduler,
  }) {
    final registry = AtomRegistry(
      scheduler: scheduler,
      initialValues: initialValues,
    );
    return buildAllWithRegistry(registry, layers).as(registry);
  }
}

// class MyService {
//   final Ref<int> counter = Ref(0);
// }
//
// Future<void> main() {}
