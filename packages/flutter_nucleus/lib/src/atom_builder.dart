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
    AtomGetter watch,
    Widget? child,
  ) builder;
  final Widget? child;

  @override
  State<AtomBuilder> createState() => _AtomBuilderState();
}

class _AtomBuilderState extends State<AtomBuilder> {
  late final _store = AtomScope.of(context);
  final _cancellers = HashMap<Atom, void Function()>();
  final _valueCache = HashMap<Atom, Object?>();

  A _watch<A>(Atom<A> atom) {
    if (!_cancellers.containsKey(atom)) {
      _cancellers[atom] = _store.subscribe(
          atom,
          () => setState(() {
                _valueCache.remove(atom);
              }));
    }

    return _valueCache[atom] ??= _store.read(atom);
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _watch, widget.child);

  @override
  void dispose() {
    for (final cancel in _cancellers.values) {
      cancel();
    }
    _cancellers.clear();

    super.dispose();
  }
}
