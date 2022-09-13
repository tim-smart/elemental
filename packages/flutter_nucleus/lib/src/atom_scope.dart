import 'package:flutter/material.dart';
import 'package:flutter_nucleus/flutter_nucleus.dart';

class AtomScope extends InheritedWidget {
  // ignore: unnecessary_late
  static late final defaultStore = Store();

  AtomScope({
    super.key,
    required super.child,
    Store? store,
  }) : _store = store ?? Store();

  final Store _store;

  @override
  bool updateShouldNotify(covariant AtomScope oldWidget) =>
      oldWidget._store != _store;

  static Store of(BuildContext context) {
    final AtomScope? result =
        context.dependOnInheritedWidgetOfExactType<AtomScope>();
    return result?._store ?? defaultStore;
  }
}
