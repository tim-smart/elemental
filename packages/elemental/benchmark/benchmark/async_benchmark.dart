import 'package:elemental/elemental.dart';

import 'utils.dart';

void main() {
  final benchmark = group('async');

  benchmark('plain', () {
    Future<int> fn() => Future.value(1).then((value) => value + 2);
    return fn();
  });

  benchmark('ZIO', () {
    return IO.succeed(1).map((_) => _ + 2).runFuture();
  });
}
