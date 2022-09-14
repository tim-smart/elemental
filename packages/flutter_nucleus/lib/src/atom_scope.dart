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
  A readAtom<A>(Atom<A, dynamic> atom) => AtomScope.of(this).read(atom);
}
