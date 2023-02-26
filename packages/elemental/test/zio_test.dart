import 'package:elemental/elemental.dart';
import 'package:test/test.dart';

void main() {
  group('tapEither', () {
    test('int', () async {
      final deferred = DeferredIO<Either<Never, int>>();
      IO.succeed(1).tapEither(deferred.completeIO).runSyncOrThrow();
      expect(await deferred.awaitIO.runOrThrow(), Either.right(1));
    });
  });
}
