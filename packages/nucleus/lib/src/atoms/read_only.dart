import 'package:nucleus/nucleus.dart';

/// See [atom].
class ReadOnlyAtom<Value> extends Atom<Value> {
  ReadOnlyAtom(this._reader);

  final AtomReader<Value> _reader;

  @override
  Value read(_) => _reader(_);
}

/// Create a read only atom that can interact with other atom's to create
/// derived state.
///
/// ```dart
/// final count = stateAtom(0);
/// final countTimesTwo = atom((get) => get(count) * 2);
/// ```
Atom<Value> atom<Value>(AtomReader<Value> create) => ReadOnlyAtom(create);
