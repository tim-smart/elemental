part of '../zio.dart';

typedef GetLayer = EIO<E, A> Function<E, A>(Layer<E, A> layer);

final _layerScopeAtom = atom((get) => Scope.closable());

class Layer<E, Service> {
  Layer._(this._make);
  final ZIO<Scope, E, Service> _make;

  factory Layer(EIO<E, Service> make) => Layer._(make.lift());
  factory Layer.scoped(ZIO<Scope, E, Service> make) => Layer._(make);

  late final _makeAtom = ReadOnlyAtom(
    (get) => _make.provide(get(_layerScopeAtom)).memoize.runSync(),
  ).keepAlive();
  final _stateAtom = StateAtom(Option<Service>.none()).keepAlive();
  late final Atom<Service> atom = ReadOnlyAtom(
    (get) => get(_stateAtom).match(
      () => throw StateError('Layer not built'),
      identity,
    ),
  ).keepAlive();

  EIO<E, Service> get getOrBuild => ZIO.from(
        (env, r) => r.get(_stateAtom).match(
              () => r
                  .get(_makeAtom)
                  .tap((service) => IO(() {
                        r.set(_stateAtom, Option.of(service));
                      }).lift())
                  ._run(env, r),
              Either.right,
            ),
      );

  EIO<E2, Unit> replace<E2>(EIO<E2, Service> build) =>
      build.flatMapRegistry((service, r) => IO(() {
            r.set(_stateAtom, Option.of(service));
            return unit;
          }));
}
