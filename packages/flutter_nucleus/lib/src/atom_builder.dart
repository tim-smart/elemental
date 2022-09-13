import 'package:flutter/widgets.dart';
import 'package:flutter_nucleus/flutter_nucleus.dart';

class AtomBuilder<A> extends StatefulWidget {
  const AtomBuilder(
    this.atom,
    this.builder, {
    Key? key,
    this.child,
  }) : super(key: key);

  final Atom<A> atom;
  final Widget Function(BuildContext context, A value, Widget? child) builder;
  final Widget? child;

  @override
  State<AtomBuilder<A>> createState() => _AtomBuilderState<A>();
}

class _AtomBuilderState<A> extends State<AtomBuilder<A>> {
  late final _notifier = AtomNotifier.from(context, widget.atom);

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
        valueListenable: _notifier,
        builder: widget.builder,
        child: widget.child,
      );

  @override
  void dispose() {
    _notifier.dispose();
    super.dispose();
  }
}
