import 'package:flutter/material.dart';
import 'package:flutter_nucleus/flutter_nucleus.dart';

class AtomScope extends InheritedWidget {
  static final defaultRegistry = AtomRegistry();

  AtomScope({
    super.key,
    required super.child,
    List<AtomInitialValue> initialValues = const [],
  }) : registry = AtomRegistry(initialValues: initialValues);

  final AtomRegistry registry;

  @override
  bool updateShouldNotify(covariant AtomScope oldWidget) =>
      oldWidget.registry != registry;

  static AtomRegistry registryOf(
    BuildContext context, {
    bool listen = true,
  }) {
    final scope = listen
        ? context.dependOnInheritedWidgetOfExactType<AtomScope>()
        : (context.getElementForInheritedWidgetOfExactType<AtomScope>()?.widget
            as AtomScope?);

    return scope?.registry ?? defaultRegistry;
  }
}
