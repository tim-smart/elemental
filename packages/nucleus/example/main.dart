import 'package:nucleus/nucleus.dart';

final count = stateAtom(0);

void main(List<String> args) async {
  final store = AtomRegistry();

  print(store.get(count));
  store.set(count, 2);
  print(store.get(count));
}
