import 'package:nucleus/nucleus.dart';

typedef ManagedAtomCreate<Value> = void Function(ManagedAtomContext<Value> ctx);

class ManagedAtomContext<T> {
  ManagedAtomContext({
    required this.get,
    required this.set,
    required this.onDispose,
    required this.previousValue,
  });

  final T previousValue;
  final AtomGetter get;
  final void Function(T value) set;
  final void Function(void Function()) onDispose;
}

class ManagedAtom<Value> extends Atom<Value, void> {
  ManagedAtom(
    this.initialValue,
    this._create,
  );

  final Value initialValue;
  final ManagedAtomCreate<Value> _create;

  @override
  Value read(AtomGetter getter) => getter(this);

  void create({
    required AtomGetter get,
    required void Function(Value) set,
    required void Function(void Function()) onDispose,
    required Value previous,
  }) {
    _create(ManagedAtomContext(
      get: get,
      set: set,
      onDispose: onDispose,
      previousValue: previous,
    ));
  }
}

// Function API

Atom<Value, void> managedAtom<Value>(
  Value initialValue,
  ManagedAtomCreate<Value> create, {
  bool? keepAlive,
}) =>
    ManagedAtom(initialValue, create);
