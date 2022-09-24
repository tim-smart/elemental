import 'package:nucleus/nucleus.dart';

/// Turn a read only atom into a writable atom that refreshes it's value when
/// written to.
///
/// ```dart
/// final refreshableUsers = atomWithRefresh((get) => getUsers());
///
/// // ...
///
/// final users = watch(refreshableUsers);
/// final refreshUsers = () => context.setAtom(refreshableUsers)(null);
/// ```
// ignore: prefer_void_to_null
WritableAtom<A, Null> atomWithRefresh<A>(AtomReader<A> create) {
  final refresher = stateAtom({});

  return ProxyAtom((get) {
    get(refresher);
    return create(get);
  }, (get, set, setSelf, _) => set(refresher, {}));
}
