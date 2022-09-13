import 'package:flutter/widgets.dart';
import 'package:flutter_nucleus/flutter_nucleus.dart';

class AtomNotifier<A> extends ChangeNotifier implements ValueNotifier<A> {
  AtomNotifier(this._store, this._atom) {
    _unsubscribe = _store.subscribe(_atom, notifyListeners);
  }

  factory AtomNotifier.from(BuildContext context, AtomBase<A> atom) =>
      AtomNotifier(AtomScope.of(context), atom);

  Store _store;
  AtomBase<A> _atom;

  late final void Function() _unsubscribe;

  @override
  A get value => _store.read(_atom);

  @override
  set value(A next) => _store.put(_atom, next);

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }
}
