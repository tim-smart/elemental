import 'package:flutter/widgets.dart';
import 'package:flutter_nucleus/flutter_nucleus.dart';
import 'package:nucleus/nucleus.dart';

class AtomNotifier<A> extends ChangeNotifier implements ValueNotifier<A> {
  AtomNotifier(this._store, this._atom);

  factory AtomNotifier.from(BuildContext context, AtomBase<A> atom) =>
      AtomNotifier(AtomScope.of(context), atom);

  Store _store;
  AtomBase<A> _atom;

  late final _unsubscribe = _store.subscribe(_atom, notifyListeners);

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
