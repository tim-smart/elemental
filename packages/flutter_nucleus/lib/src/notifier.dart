import 'package:flutter/widgets.dart';
import 'package:flutter_nucleus/flutter_nucleus.dart';

class AtomNotifier<A> extends LazyChangeNotifier implements ValueNotifier<A> {
  AtomNotifier(this._store, this._atom);

  factory AtomNotifier.from(BuildContext context, Atom<A> atom) =>
      AtomNotifier(AtomScope.of(context), atom);

  late void Function() _unsubscribe;
  final Store _store;
  final Atom<A> _atom;

  @override
  void resume() {
    _unsubscribe = _store.subscribe(_atom, _onChange);
  }

  @override
  void pause() {
    _unsubscribe();
  }

  void _onChange() {
    _value = null;
    notifyListeners();
  }

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
}
