import 'package:nucleus/nucleus.dart';

typedef ManagedAtomCreate<Value> = void Function(ManagedAtomContext<Value> ctx);

class ManagedAtomContext<T> {
  ManagedAtomContext({
    required this.get,
    required this.set,
    required this.onDispose,
    required this.previousValue,
  });

  final T? previousValue;
  final AtomGetter get;
  final void Function(T value) set;
  final void Function(void Function()) onDispose;
}

class ManagedAtom<Value> extends Atom<Value> {
  ManagedAtom(
    this._lazyInitialValue,
    this._create,
  );

  final Value Function() _lazyInitialValue;
  Value get initialValue => _lazyInitialValue();
  final ManagedAtomCreate<Value> _create;

  @override
  Value read(AtomGetter getter, AtomOnDispose onDispose) => getter(this);

  void create({
    required AtomGetter get,
    required void Function(Value) set,
    required void Function(void Function()) onDispose,
    required Value? previousValue,
  }) {
    _create(ManagedAtomContext(
      get: get,
      set: set,
      onDispose: onDispose,
      previousValue: previousValue,
    ));
  }
}

// Function API

Atom<Value> managedAtom<Value>(
  Value Function() lazyInitialValue,
  ManagedAtomCreate<Value> create,
) =>
    ManagedAtom(lazyInitialValue, create);
