import 'package:elemental/elemental.dart';
import 'package:elemental_isolates/elemental_isolates.dart';
import 'package:test/test.dart';

void main() {
  group('onIsolate', () {
    test('works', () async {
      final result =
          await List.generate(30, (i) => IO.succeed("got: $i").onIsolate)
              .collectPar
              .runOrThrow();
      final expected = List.generate(30, (i) => "got: $i");
      expect(result.toList(), expected);
    });
  });
}
