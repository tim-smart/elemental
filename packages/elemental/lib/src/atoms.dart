import 'package:elemental/elemental.dart';

final runtimeAtom = atom((get) => Runtime.defaultRuntime);

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
