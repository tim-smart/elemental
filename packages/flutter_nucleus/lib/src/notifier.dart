import 'package:flutter/widgets.dart';
import 'package:flutter_nucleus/flutter_nucleus.dart';

class AtomNotifier<A> extends ChangeNotifier implements ValueNotifier<A> {
  AtomNotifier(this._store, this._atom) {
    _unsubscribe = _store.subscribe(_atom, () {
      _value = null;
      notifyListeners();
    });
  }

  factory AtomNotifier.from(BuildContext context, Atom<A> atom) =>
      AtomNotifier(AtomScope.of(context), atom);

  late final void Function() _unsubscribe;
  final Store _store;
  final Atom<A> _atom;

  A? _value;

  @override
  A get value {
    if (_value == null) {
      _value = _store.read(_atom);
      return _value!;
    }

    return _value!;
  }

  @override
  set value(A next) {
    _store.put(_atom, next);
  }

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }
}
