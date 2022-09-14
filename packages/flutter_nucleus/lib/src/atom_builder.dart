import 'dart:collection';

import 'package:flutter/widgets.dart';
import 'package:flutter_nucleus/flutter_nucleus.dart';

typedef AtomBuilderGet = AtomNotifier<A> Function<A>(Atom<A, dynamic> atom);

class AtomBuilder extends StatefulWidget {
  const AtomBuilder(
    this.builder, {
    Key? key,
    this.child,
  }) : super(key: key);

  final Widget Function(
    BuildContext context,
    AtomBuilderGet get,
    Widget? child,
  ) builder;
  final Widget? child;

  @override
  State<AtomBuilder> createState() => _AtomBuilderState();
}

class _AtomBuilderState extends State<AtomBuilder> {
  late final _store = AtomScope.of(context);
  final _notifiers = HashMap<Atom, AtomNotifier>();

  AtomNotifier<A> _get<A>(Atom<A, dynamic> atom) {
    if (_notifiers.containsKey(atom)) {
      return _notifiers[atom] as AtomNotifier<A>;
    }

    final notifier = AtomNotifier(_store, atom);
    notifier.addListener(_onChange);

    return notifier;
  }

  void _onChange() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _get, widget.child);

  @override
  void dispose() {
    for (final notifier in _notifiers.values) {
      notifier.dispose();
    }
    _notifiers.clear();

    super.dispose();
  }
}
