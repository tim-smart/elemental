import 'package:nucleus/nucleus.dart';

final count = atom(0);

void main(List<String> args) async {
  final store = Store();

  print(store.read(count));
  store.put(count, 2);
  print(store.read(count));
}
