import 'package:elemental/elemental.dart';

/// The default [Runtime] used by used by [zioRefAtomSync] and [zioAtom].
/// Also used by the extension methods on [AtomContext] and [BuildContext].
final runtimeAtom = atom((get) {
  final runtime = Runtime();
  get.onDispose(() => runtime.dispose.run());
  return runtime;
});

/// Creates an [Atom] from a [Ref] contained in a [ZIO]. It will throw an error
/// if the [Ref] cannot be accessed synchronously.
AtomWithParent<A, Atom<Ref<A>>> zioRefAtomSync<E, A>(EIO<E, Ref<A>> zio) =>
    atomWithParent(
      atom((get) {
        try {
          return get(runtimeAtom).runSyncOrThrow(zio);
        } on Interrupted {
          throw "zioRefAtomSync: Could not access Ref. Maybe a Layer has not been built yet?";
        }
      }),
      (get, parent) {
        final ref = get(parent);

        get.onDispose(ref.stream.listen((a) {
          get.setSelf(a);
        }).cancel);

        return ref.unsafeGet();
      },
    );

/// Creates an [Atom] of [ZIORunnerState]'s from the given [ZIO].
///
/// Very similar to [futureAtom] / [FutureValue];
AtomWithParent<ZIORunnerState<E, A>, Atom<ZIORunner<E, A>>> zioAtom<E, A>(
  EIO<E, A> zio, {
  bool runImmediately = true,
}) =>
    atomWithParent(atom((get) {
      final runner = zio.runner.runSyncOrThrow(get(runtimeAtom));

      get.onDispose(runner.dispose);

      if (runImmediately) {
        runner.runOrThrow();
      }

      return runner;
    }), (get, parent) {
      final runner = get(parent);

      get.onDispose(runner.stream.listen((a) {
        get.setSelf(a);
      }).cancel);

      return runner.state;
    });
