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

  void setAtom<A>(WritableAtom<dynamic, A> atom, A value) =>
      AtomScope.of(this).put(atom, value);

  void updateAtom<R, W>(WritableAtom<R, W> atom, W Function(R value) f) {
    final store = AtomScope.of(this);
    return store.put(atom, f(store.read(atom)));
  }
}
