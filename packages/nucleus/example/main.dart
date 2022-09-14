import 'package:nucleus/nucleus.dart';

final count = stateAtom(0);

void main(List<String> args) async {
  final store = Store();

  print(store.read(count));
  store.put(count, 2);
  print(store.read(count));
}
