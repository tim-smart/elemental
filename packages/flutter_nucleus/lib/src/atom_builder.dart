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

typedef _CancelMap = HashMap<Atom, void Function()>;

class _AtomBuilderState extends State<AtomBuilder> {
  late var _registry = AtomScope.registryOf(context);
  final _valueCache = HashMap<Atom, Object?>();

  _CancelMap? _previousMounts;
  _CancelMap _mounts = HashMap();

  _CancelMap? _previousSubscriptions;
  _CancelMap _subscriptions = HashMap();

  A _watch<A>(
    Atom<A> atom, {
    bool listen = true,
  }) {
    if (listen && !_subscriptions.containsKey(atom)) {
      if (_previousSubscriptions != null &&
          _previousSubscriptions!.containsKey(atom)) {
        _subscriptions[atom] = _previousSubscriptions![atom]!;
        _previousSubscriptions!.remove(atom);
      } else {
        _subscriptions[atom] = _registry.subscribe(
          atom,
          () {
            final nextValue = _registry.get(atom);
            if (nextValue == _valueCache[atom]) return;
            setState(() {
              _valueCache[atom] = nextValue;
            });
          },
        );
      }
    } else if (!_mounts.containsKey(atom)) {
      if (_previousMounts != null && _previousMounts!.containsKey(atom)) {
        _mounts[atom] = _previousMounts![atom]!;
        _previousMounts!.remove(atom);
      } else {
        _mounts[atom] = _registry.mount(atom);
      }
    }

    return _valueCache.putIfAbsent(atom, () => _registry.get(atom)) as A;
  }

  @override
  Widget build(BuildContext context) {
    _previousSubscriptions = _subscriptions;
    _subscriptions = HashMap();
    _previousMounts = _mounts;
    _mounts = HashMap();

    final result = widget.builder(context, _watch, widget.child);

    if (_previousSubscriptions!.isNotEmpty) {
      for (final e in _previousSubscriptions!.entries) {
        e.value();
        _valueCache.remove(e.key);
      }
    }

    if (_previousMounts!.isNotEmpty) {
      for (final e in _previousMounts!.entries) {
        e.value();
        _valueCache.remove(e.key);
      }
    }

    _previousSubscriptions = null;
    _previousMounts = null;

    return result;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final newRegistry = AtomScope.registryOf(context);
    if (newRegistry != _registry) {
      _registry = newRegistry;
      _dispose();
    }
  }

  void _dispose() {
    for (final cancel in _subscriptions.values) {
      cancel();
    }
    _subscriptions.clear();

    for (final cancel in _mounts.values) {
      cancel();
    }
    _mounts.clear();

    _valueCache.clear();
  }

  @override
  void dispose() {
    _dispose();
    super.dispose();
  }
}
