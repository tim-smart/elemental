import 'package:elemental/elemental.dart';

final runtimeAtom = atom((get) => Runtime.defaultRuntime);

AtomWithParent<A, Atom<Ref<A>>> zioRefAtomSync<E, A>(EIO<E, Ref<A>> zio) =>
    atomWithParent(
      atom((get) => get(runtimeAtom).runSyncOrThrow(zio)),
      (get, parent) {
        final ref = get(parent);

        get.onDispose(ref.stream.listen((a) {
          get.setSelf(a);
        }).cancel);

        return ref.unsafeGet();
      },
    );

AtomWithParent<A, Atom<Ref<A>>> _refAtomWrap<A>(Atom<Ref<A>> atom) =>
    atomWithParent(atom, (get, parent) {
      final ref = get(parent);

      get.onDispose(ref.stream.listen((a) {
        get.setSelf(a);
      }).cancel);

      return ref.unsafeGet();
    });

ReadOnlyAtom<Ref<A>> refAtomOnly<A>(A a) => atom((get) {
      final scope = Scope.closable();
      get.onDispose(() {
        scope.closeScopeIO.run();
      });
      return Ref.makeScope(a).provide(scope).runSyncOrThrow();
    });

AtomWithParent<A, Atom<Ref<A>>> refAtom<A>(A initialValue) =>
    _refAtomWrap(refAtomOnly(initialValue));

ReadOnlyAtom<Ref<A>> refAtomWithStorageOnly<A>(
  A defaultValue, {
  required String key,
  required A Function(dynamic) fromJson,
  required dynamic Function(A) toJson,
  required Atom<NucleusStorage> storage,
}) =>
    atomWithStorage<Ref<A>, A>((get, read, write) {
      final scope = Scope.closable();
      get.onDispose(() {
        scope.closeScopeIO.run();
      });

      final ref =
          Ref.makeScope(read() ?? defaultValue).provide(scope).runSyncOrThrow();

      get.onDispose(ref.stream.listen((a) {
        write(a);
      }).cancel);

      return ref;
    }, key: key, fromJson: fromJson, toJson: toJson, storage: storage);

AtomWithParent<A, Atom<Ref<A>>> refAtomWithStorage<A>(
  A initialValue, {
  required String key,
  required A Function(dynamic) fromJson,
  required dynamic Function(A) toJson,
  required Atom<NucleusStorage> storage,
}) =>
    _refAtomWrap(refAtomWithStorageOnly(
      initialValue,
      key: key,
      fromJson: fromJson,
      toJson: toJson,
      storage: storage,
    ));
