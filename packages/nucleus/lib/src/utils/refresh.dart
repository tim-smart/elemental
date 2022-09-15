import 'package:nucleus/nucleus.dart';

WritableAtom<A, void> atomWithRefresh<A>(AtomReader<A> create) {
  final refresher = stateAtom({})..autoDispose();

  return ProxyAtom((get, onDispose) {
    get(refresher);
    return create(get, onDispose);
  }, (get, set, _) => set(refresher, {}));
}
