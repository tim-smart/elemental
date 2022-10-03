import 'package:flutter/widgets.dart';
import 'package:flutter_nucleus/flutter_nucleus.dart';

typedef WidgetAtomReader = Widget Function(
  BuildContext context,
  AtomContext<Widget> get,
  Widget? child,
);

class AtomBuilder extends StatefulWidget {
  const AtomBuilder(
    this.builder, {
    Key? key,
    this.child,
    this.debugName,
  }) : super(key: key);

  final WidgetAtomReader builder;
  final Widget? child;
  final String? debugName;

  @override
  State<AtomBuilder> createState() => _AtomBuilderState();
}

class _AtomBuilderState extends State<AtomBuilder> {
  late var _registry = AtomScope.registryOf(context);

  late final RefreshableReadOnlyAtom<Widget> _atom;

  Widget? _widget;
  VoidCallback? _cancel;

  @override
  void initState() {
    super.initState();

    _atom = atom(_create).refreshable();

    if (widget.debugName != null) {
      _atom.setName(widget.debugName!);
    }
  }

  Widget _create(AtomContext<Widget> get) =>
      widget.builder(context, get, widget.child);

  void _setWidget(Widget widget) {
    setState(() {
      _widget = widget;
    });
  }

  @override
  Widget build(BuildContext context) {
    _widget ??= _registry.get(_atom);
    _cancel ??= _registry.subscribe<Widget>(_atom, _setWidget);
    return _widget!;
  }

  @override
  void didUpdateWidget(covariant AtomBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    _registry.refresh(_atom);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final registry = AtomScope.registryOf(context);
    if (registry != _registry) {
      _registry = registry;
      _cancel?.call();
      _cancel = null;
      _widget = null;
    }
  }

  @override
  void dispose() {
    _cancel?.call();
    _cancel = null;
    _widget = null;

    super.dispose();
  }
}
