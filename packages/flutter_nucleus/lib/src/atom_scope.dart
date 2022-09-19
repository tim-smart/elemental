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

extension NucleusBuildContextExt on BuildContext {
  /// Read an atom once
  A getAtom<A>(Atom<A> atom) => AtomScope.registryOf(this).get(atom);

  /// Create a setter function for an atom.
  void Function(A value) setAtom<A>(WritableAtom<dynamic, A> atom) {
    final registry = AtomScope.registryOf(this);
    return (value) => registry.set(atom, value);
  }

  /// Create an updater function for an atom.
  void Function(W Function(R value)) updateAtom<R, W>(WritableAtom<R, W> atom) {
    final registry = AtomScope.registryOf(this);
    return (f) => registry.set(atom, f(registry.get(atom)));
  }

  /// Subscribe to an atom.
  ///
  /// Returns a function that cancels the subscription.
  void Function() subscribeAtom(Atom atom, void Function() onChange) =>
      AtomScope.registryOf(this).subscribe(atom, onChange);

  /// Subscribe to an atom without listening for changes.
  ///
  /// Returns a function that un-mounts the atom.
  void Function() mountAtom(Atom atom) =>
      AtomScope.registryOf(this).mount(atom);
}
