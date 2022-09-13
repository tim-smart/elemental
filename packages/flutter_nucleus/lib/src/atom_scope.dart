import 'package:flutter/material.dart';
import 'package:nucleus/nucleus.dart';

class AtomScope extends InheritedWidget {
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
    assert(result != null, 'No AtomScope found in context');
    return result!._store;
  }
}
