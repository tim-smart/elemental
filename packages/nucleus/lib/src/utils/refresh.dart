import 'package:nucleus/nucleus.dart';

// ignore: prefer_void_to_null
WritableAtom<A, Null> atomWithRefresh<A>(AtomReader<A> create) {
  final refresher = stateAtom({})..autoDispose();

  return ProxyAtom((get, onDispose) {
    get(refresher);
    return create(get, onDispose);
  }, (get, set, _) => set(refresher, {}));
}
