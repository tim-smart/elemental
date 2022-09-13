import 'package:fast_immutable_collections/fast_immutable_collections.dart';

typedef AtomGetter = A Function<A>(Atom<A> atom);
typedef AtomReader<Value> = Value Function(AtomGetter get);
typedef AtomInitialValue = Tuple2<Atom, dynamic>;

int _globalKeyCount = 0;
String _createKey() => "nucleus${_globalKeyCount++}";

abstract class Atom<Value> {
  Atom({bool? keepAlive}) : keepAlive = keepAlive ?? false;

  Symbol _symbol = Symbol(_createKey());
  Symbol get symbol => _symbol;
  final bool keepAlive;

  Value read(AtomGetter getter);

  @override
  operator ==(Object? other) => other is Atom && other._symbol == _symbol;

  @override
  int get hashCode => symbol.hashCode;

  AtomInitialValue withInitialValue(Value value) => Tuple2(this, value);
}

// Family creator

Atom<Value> Function(Arg arg) atomFamily<Value, Arg>(
  Atom<Value> Function(Arg arg) create,
) {
  final familyKey = _createKey();
  return (arg) {
    final atom = create(arg);
    atom._symbol = Symbol("${familyKey}_${arg.hashCode}");
    return atom;
  };
}
