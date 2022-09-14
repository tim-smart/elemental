import 'package:flutter/widgets.dart';
import 'package:flutter_nucleus/flutter_nucleus.dart';

class AtomNotifier<R> extends LazyChangeNotifier implements ValueNotifier<R> {
  AtomNotifier(this._store, this._atom);

  factory AtomNotifier.from(BuildContext context, Atom<R, dynamic> atom) =>
      AtomNotifier(AtomScope.of(context), atom);

  late void Function() _unsubscribe;
  final Store _store;
  final Atom<R, dynamic> _atom;

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

  R? _value;

  @override
  R get value {
    if (_value == null) {
      _value = _store.read(_atom);
      return _value!;
    }

    return _value!;
  }

  @override
  set value(dynamic next) {
    _store.put(_atom, next);
  }
}
