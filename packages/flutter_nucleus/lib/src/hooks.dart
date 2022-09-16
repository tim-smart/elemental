import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart' hide Store;
import 'package:flutter_nucleus/flutter_nucleus.dart';

A useAtom<A>(
  Atom<A> atom, {
  bool listen = true,
}) =>
    use(_AtomHook(atom, listen: listen));

class _AtomHook<A> extends Hook<A> {
  const _AtomHook(
    this.atom, {
    required this.listen,
  });

  final Atom<A> atom;
  final bool listen;

  @override
  _AtomHookState<A> createState() => _AtomHookState();
}

class _AtomHookState<A> extends HookState<A, _AtomHook<A>> {
  late A _value;
  void Function()? _cancel;

  void _setup(BuildContext context) {
    final store = AtomScope.storeOf(context);
    _value = store.read(hook.atom);

    if (hook.listen) {
      _cancel = store.subscribe(
        hook.atom,
        () => setState(() {
          _value = store.read(hook.atom);
        }),
      );
    } else {
      _cancel = store.mount(hook.atom);
    }
  }

  @override
  void didUpdateHook(_AtomHook<A> oldHook) {
    super.didUpdateHook(oldHook);

    if (hook.atom != oldHook.atom) {
      _cancel?.call();
      _cancel = null;
    }
  }

  @override
  A build(BuildContext context) {
    if (_cancel == null) {
      _setup(context);
    }

    return _value;
  }

  @override
  void dispose() {
    _cancel?.call();
    _cancel = null;

    super.dispose();
  }

  @override
  Object? get debugValue => _value;

  @override
  String? get debugLabel => 'useAtom<$A>';
}
