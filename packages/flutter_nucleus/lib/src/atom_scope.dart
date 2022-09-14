import 'package:flutter/material.dart';
import 'package:flutter_nucleus/flutter_nucleus.dart';

class AtomScope extends InheritedWidget {
  // ignore: unnecessary_late
  static late final defaultStore = Store();

  AtomScope({
    super.key,
    required super.child,
    List<AtomInitialValue> initialValues = const [],
  }) : store = Store(initialValues: initialValues);

  final Store store;

  @override
  bool updateShouldNotify(covariant AtomScope oldWidget) =>
      oldWidget.store != store;

  static Store of(BuildContext context) {
    final AtomScope? result =
        context.dependOnInheritedWidgetOfExactType<AtomScope>();
    return result?.store ?? defaultStore;
  }
}

extension NucleusBuildContextExt on BuildContext {
  A getAtom<A>(Atom<A> atom) => AtomScope.of(this).read(atom);

  void Function(A value) setAtom<A>(WritableAtom<dynamic, A> atom) {
    final store = AtomScope.of(this);
    return (value) => store.put(atom, value);
  }

  void Function(W Function(R value)) updateAtom<R, W>(WritableAtom<R, W> atom) {
    final store = AtomScope.of(this);
    return (f) => store.put(atom, f(store.read(atom)));
  }
}
