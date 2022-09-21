part of '../atoms.dart';

/// The base class for all atoms.
///
/// An atom is a special identifiet, that points to some state in an [AtomRegistry].
///
/// It also contains configuration that determines how its state is read, or
/// written (see [WritableAtom]).
abstract class Atom<T> {
  /// Used by the registry to read the atoms value.
  T read(AtomContext<T> ctx);

  /// Should this atoms state be kept, even if it isnt being used?
  ///
  /// Defaults to `false`.
  bool get shouldKeepAlive => _keepAlive;
  bool _keepAlive = false;

  /// Prevent the state of this atom from being automatically disposed.
  void keepAlive() {
    _keepAlive = true;
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

  /// Used by the registry.
  T $read(AtomContext ctx) => read(_AtomContextProxy._(ctx));

  /// Used by the registry.
  void Function()? $onNodeRemove;

  @override
  String toString() => "$runtimeType(name: $name)";
}

/// Represents an [Atom] that can be written to.
abstract class WritableAtom<R, W> extends Atom<R> {
  /// When the atom recieves a write with the given [value], this method
  /// determines the outcome.
  void write(GetAtom get, SetAtom set, SetSelf<R> setSelf, W value);
}

/// Passed to the [Atom.read] method, allowing you to interact with other atoms
/// and manage the lifecycle of your state.
abstract class AtomContext<T> {
  /// Get the value for the given [atom].
  R call<R>(Atom<R> atom);

  /// Get the value for the given [atom].
  R get<R>(Atom<R> atom);

  /// Set the value for the given [atom].
  void set<R, W>(WritableAtom<R, W> atom, W value);

  /// Set the value for the current atom.
  void setSelf(T value);

  /// Subscribe to the given [atom].
  void Function() subscribe(Atom atom, void Function() handler);

  /// Register an [cb] function, that is called when the atom is invalidated or
  /// disposed.
  ///
  /// Can be called multiple times.
  void onDispose(void Function() cb);

  /// The previous value of this atom.
  T? get previousValue;
}

class _AtomContextProxy<T> implements AtomContext<T> {
  _AtomContextProxy._(this._parent);

  final AtomContext _parent;

  @override
  late final T? previousValue = _parent.previousValue;

  @override
  A call<A>(Atom<A> atom) => _parent.get(atom);

  @override
  A get<A>(Atom<A> atom) => _parent.get(atom);

  @override
  void set<R, W>(WritableAtom<R, W> atom, W value) => _parent.set(atom, value);

  @override
  void setSelf(T value) => _parent.setSelf(value);

  @override
  void Function() subscribe(Atom atom, void Function() handler) =>
      _parent.subscribe(atom, handler);

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
