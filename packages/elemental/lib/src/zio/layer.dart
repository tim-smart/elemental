part of '../zio.dart';

typedef GetLayer = EIO<E, A> Function<E, A>(Layer<E, A> layer);

final _layerScopeAtom = atom((get) => Scope.closable());

class Layer<E, Service> {
  Layer._(ZIO<Scope, E, Service> make)
      : _makeAtom = ReadOnlyAtom(
          (get) => make.provide(get(_layerScopeAtom)).memoize.runSync(),
        ).keepAlive(),
        _stateAtom = StateAtom(Option<Service>.none()).keepAlive() {
    atom = ReadOnlyAtom(
      (get) => get(_stateAtom).match(
        () => throw StateError('Layer not built'),
        identity,
      ),
    ).keepAlive();
  }

  Layer._withAtoms(this._makeAtom, this._stateAtom, this.atom);

  factory Layer(EIO<E, Service> make) => Layer._(make.lift());
  factory Layer.scoped(ZIO<Scope, E, Service> make) => Layer._(make);

  late final ReadOnlyAtom<EIO<E, Service>> _makeAtom;
  final WritableAtom<Option<Service>, Option<Service>> _stateAtom;
  late final Atom<Service> atom;

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

  Layer<E2, Service> replace<E2>(EIO<E2, Service> build) => Layer._withAtoms(
        ReadOnlyAtom((get) => build.memoize.runSync()),
        _stateAtom,
        atom,
      );

  Layer<E2, Service> replaceScoped<E2>(ZIO<Scope, E2, Service> build) =>
      Layer._withAtoms(
        ReadOnlyAtom(
          (get) => build.provide(get(_layerScopeAtom)).memoize.runSync(),
        ),
        _stateAtom,
        atom,
      );
}
