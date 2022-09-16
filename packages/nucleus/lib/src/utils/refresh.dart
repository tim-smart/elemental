import 'package:nucleus/nucleus.dart';

// ignore: prefer_void_to_null
WritableAtom<A, Null> atomWithRefresh<A>(AtomReader<A> create) {
  final refresher = stateAtom({});

  return ProxyAtom((get) {
    get(refresher);
    return create(get);
  }, (get, set, _) => set(refresher, {}));
}
