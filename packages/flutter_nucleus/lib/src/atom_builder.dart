import 'dart:collection';

import 'package:flutter/widgets.dart';
import 'package:flutter_nucleus/flutter_nucleus.dart';

class AtomBuilder extends StatefulWidget {
  const AtomBuilder(
    this.builder, {
    Key? key,
    this.child,
  }) : super(key: key);

  final Widget Function(
    BuildContext context,
    A Function<A>(Atom<A> atom, {bool listen}) watch,
    Widget? child,
  ) builder;
  final Widget? child;

  @override
  State<AtomBuilder> createState() => _AtomBuilderState();
}

class _AtomBuilderState extends State<AtomBuilder> {
  late var _store = AtomScope.storeOf(context);
  final _cancellers = HashMap<Atom, void Function()>();
  final _valueCache = HashMap<Atom, Object?>();

  A _watch<A>(
    Atom<A> atom, {
    bool listen = true,
  }) {
    if (!_cancellers.containsKey(atom)) {
      if (listen) {
        _cancellers[atom] = _store.subscribe(
          atom,
          () => setState(() => _valueCache.remove(atom)),
        );
      } else {
        _cancellers[atom] = _store.mount(atom);
      }
    }

    return (_valueCache[atom] ??= _store.read(atom)) as A;
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _watch, widget.child);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final newStore = AtomScope.storeOf(context);
    if (newStore != _store) {
      _store = newStore;

      for (final cancel in _cancellers.values) {
        cancel();
      }
      _cancellers.clear();
      _valueCache.clear();
    }
  }

  @override
  void dispose() {
    for (final cancel in _cancellers.values) {
      cancel();
    }
    _cancellers.clear();
    _valueCache.clear();

    super.dispose();
  }
}
