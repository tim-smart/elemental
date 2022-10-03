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

class _AtomContextProxy<T> implements AtomContext<T> {
  _AtomContextProxy(this._parent);

  final AtomContext _parent;

  @override
  T? self() => _parent.self();

  @override
  A call<A>(Atom<A> atom) => _parent.get(atom);

  @override
  A get<A>(Atom<A> atom) => _parent.get(atom);

  @override
  R once<R>(Atom<R> atom) => _parent.once(atom);

  @override
  void set<R, W>(WritableAtom<R, W> atom, W value) => _parent.set(atom, value);

  @override
  void setSelf(T value) => _parent.setSelf(value);

  @override
  void refresh(RefreshableAtom atom) => _parent.refresh(atom);

  @override
  void refreshSelf() => _parent.refreshSelf();

  @override
  void subscribe<A>(
    Atom<A> atom,
    void Function(A value) handler, {
    bool fireImmediately = false,
  }) =>
      _parent.subscribe(atom, handler, fireImmediately: fireImmediately);

  @override
  Stream<A> stream<A>(Atom<A> atom) => _parent.stream(atom);

  @override
  void subscribeWithPrevious<A>(
    Atom<A> atom,
    void Function(A? previous, A value) handler, {
    bool fireImmediately = false,
  }) =>
      _parent.subscribeWithPrevious(
        atom,
        handler,
        fireImmediately: fireImmediately,
      );

  @override
  void mount(Atom atom) => _parent.mount(atom);

  @override
  void onDispose(void Function() cb) => _parent.onDispose(cb);
}
