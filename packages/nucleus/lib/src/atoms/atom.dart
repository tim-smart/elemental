part of '../atoms.dart';

/// The base class for all atoms.
///
/// An atom is a special identifiet, that points to some state in an [AtomRegistry].
///
/// It also contains configuration that determines how its state is read, or
/// written (see [WritableAtom]).
abstract class Atom<T> {
  /// Used by the registry to read the atoms value.
  T $read(AtomContext<T> ctx);

  /// Used by the registry.
  T $$read(AtomContext ctx) => $read(_AtomContextProxy._(ctx));

  /// Determines refresh behaviour.
  void $refresh(void Function(Atom atom) refresh) => refresh(this);

  /// Should this atoms state be kept, even if it isnt being used?
  ///
  /// Defaults to `false`.
  bool get shouldKeepAlive => _keepAlive;
  bool _keepAlive = false;

  /// Prevent the state of this atom from being automatically disposed.
  void keepAlive() {
    _keepAlive = true;
  }

  var _refreshable = false;

  /// Determines whether the atom can be manually refreshed.
  bool get isRefreshable => _refreshable;

  /// Allow this atom to be manually refreshed
  void refreshable() {
    _refreshable = true;
  }

  /// Set a name for debugging
  String? name;

  /// Set a name for debugging
  void setName(String name) {
    this.name = name;
  }

  /// Create an initial value override, which can be given to an [AtomScope] or
  /// [AtomRegistry].
  AtomInitialValue withInitialValue(T value) => AtomInitialValue(this, value);

  @override
  String toString() => "$runtimeType(name: $name)";
}

/// Represents an [Atom] that can be written to.
abstract class WritableAtom<R, W> extends Atom<R> {
  /// When the atom recieves a write with the given [value], this method
  /// determines the outcome.
  void $write(GetAtom get, SetAtom set, SetSelf<R> setSelf, W value);
}

/// Passed to the [Atom.$read] method, allowing you to interact with other atoms
/// and manage the lifecycle of your state.
abstract class AtomContext<T> {
  /// Get the value for the given [atom].
  R call<R>(Atom<R> atom);

  /// Get the value for the given [atom].
  R get<R>(Atom<R> atom);

  /// Get the value of the current atom.
  T? self();

  /// Set the value for the given [atom].
  void set<R, W>(WritableAtom<R, W> atom, W value);

  /// Set the value for the current atom.
  void setSelf(T value);

  /// Refresh the givem [atom].
  void refresh(Atom atom);

  /// Refresh the current atom
  void refreshSelf();

  /// Subscribe to the given [atom].
  void Function() subscribe<A>(Atom<A> atom, void Function(A value) handler);

  /// Subscribe to the given [atom].
  void Function() subscribeWithPrevious<A>(
    Atom<A> atom,
    void Function(A? previous, A value) handler,
  );

  /// Subscribe to the given [atom].
  Stream<A> stream<A>(Atom<A> atom);

  /// Register an [cb] function, that is called when the atom is invalidated or
  /// disposed.
  ///
  /// Can be called multiple times.
  void onDispose(void Function() cb);
}

class _AtomContextProxy<T> implements AtomContext<T> {
  _AtomContextProxy._(this._parent);

  final AtomContext _parent;

  @override
  T? self() => _parent.self();

  @override
  A call<A>(Atom<A> atom) => _parent.get(atom);

  @override
  A get<A>(Atom<A> atom) => _parent.get(atom);

  @override
  void set<R, W>(WritableAtom<R, W> atom, W value) => _parent.set(atom, value);

  @override
  void setSelf(T value) => _parent.setSelf(value);

  @override
  void refresh(Atom atom) => _parent.refresh(atom);

  @override
  void refreshSelf() => _parent.refreshSelf();

  @override
  void Function() subscribe<A>(Atom<A> atom, void Function(A value) handler) =>
      _parent.subscribe(atom, handler);

  @override
  Stream<A> stream<A>(Atom<A> atom) => _parent.stream(atom);

  @override
  void Function() subscribeWithPrevious<A>(
    Atom<A> atom,
    void Function(A? previous, A value) handler,
  ) =>
      _parent.subscribeWithPrevious(atom, handler);

  @override
  void onDispose(void Function() cb) => _parent.onDispose(cb);
}

typedef AtomReader<R> = R Function(AtomContext<R> get);

/// Returned from [Atom.withInitialValue] for passing to a [AtomRegistry] or
/// [AtomScope].
class AtomInitialValue<A> {
  const AtomInitialValue(this.atom, this.value);
  final Atom<A> atom;
  final A value;
}
