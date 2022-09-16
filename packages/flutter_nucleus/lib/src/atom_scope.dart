import 'package:flutter/material.dart';
import 'package:flutter_nucleus/flutter_nucleus.dart';

class AtomScope extends InheritedWidget {
  static final defaultStore = Store();

  AtomScope({
    super.key,
    required super.child,
    List<AtomInitialValue> initialValues = const [],
  }) : store = Store(initialValues: initialValues);

  final Store store;

  @override
  bool updateShouldNotify(covariant AtomScope oldWidget) =>
      oldWidget.store != store;

  static Store storeOf(
    BuildContext context, {
    bool listen = true,
  }) {
    final scope = listen
        ? context.dependOnInheritedWidgetOfExactType<AtomScope>()
        : (context.getElementForInheritedWidgetOfExactType<AtomScope>()?.widget
            as AtomScope?);

    return scope?.store ?? defaultStore;
  }
}

extension NucleusBuildContextExt on BuildContext {
  /// Read an atom once
  A getAtom<A>(Atom<A> atom) => AtomScope.storeOf(this).read(atom);

  /// Create a setter function for an atom.
  void Function(A value) setAtom<A>(WritableAtom<dynamic, A> atom) {
    final store = AtomScope.storeOf(this);
    return (value) => store.put(atom, value);
  }

  /// Create an updater function for an atom.
  void Function(W Function(R value)) updateAtom<R, W>(WritableAtom<R, W> atom) {
    final store = AtomScope.storeOf(this);
    return (f) => store.put(atom, f(store.read(atom)));
  }

  /// Subscribe to an atom.
  ///
  /// Returns a function that cancels the subscription.
  void Function() subscribeAtom(Atom atom, void Function() onChange) =>
      AtomScope.storeOf(this).subscribe(atom, onChange);

  /// Subscribe to an atom without listening for changes.
  ///
  /// Returns a function that un-mounts the atom.
  void Function() mountAtom(Atom atom) => AtomScope.storeOf(this).mount(atom);
}
