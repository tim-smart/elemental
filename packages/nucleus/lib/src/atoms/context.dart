part of '../atoms.dart';

/// Passed to the [Atom.$read] method, allowing you to interact with other atoms
/// and manage the lifecycle of your state.
abstract class AtomContext<T> {
  /// Get the value for the given [atom].
  R call<R>(Atom<R> atom);

  /// Get the value for the given [atom].
  R get<R>(Atom<R> atom);

  /// Get the value for the given [atom] once.
  R once<R>(Atom<R> atom);

  /// Get the value of the current atom.
  T? self();

  /// Set the value for the given [atom].
  void set<R, W>(WritableAtom<R, W> atom, W value);

  /// Set the value for the current atom.
  void setSelf(T value);

  /// Refresh the givem [atom].
  void refresh(RefreshableAtom atom);

  /// Refresh the current atom
  void refreshSelf();

  /// Subscribe to the given [atom], automatically cancelling the subscription
  /// when this atom is disposed.
  void subscribe<A>(
    Atom<A> atom,
    void Function(A value) handler, {
    bool fireImmediately = false,
  });

  /// Subscribe to the given [atom], automatically cancelling the subscription
  /// when this atom is disposed.
  void subscribeWithPrevious<A>(
    Atom<A> atom,
    void Function(A? previous, A value) handler, {
    bool fireImmediately = false,
  });

  /// Subscribe to the given [atom].
  Stream<A> stream<A>(Atom<A> atom);

  /// Subscribe to the given [atom] without listening for changes.
  void mount(Atom atom);

  /// Register an [cb] function, that is called when the atom is invalidated or
  /// disposed.
  ///
  /// Can be called multiple times.
  void onDispose(void Function() cb);
}
