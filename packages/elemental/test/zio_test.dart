import 'package:elemental/elemental.dart';
import 'package:test/test.dart';

void main() {
  group('succeed', () {
    test('success', () {
      expect(IO.succeed(1).runSync(), Exit.right(1));
    });
  });

  group('fail', () {
    test('failure', () {
      expect(EIO.fail(1).runSync(), Exit.left(const Failure(1)));
    });
  });

  group('ZIO', () {
    test('success', () {
      expect(IO(() => 1).runSync(), Exit.right(1));
    });

    test('failure', () {
      expect(IO(() => throw 'fail').runSync(),
          Exit.left(Defect<Never>.current('fail')));
    });
  });

  group('map', () {
    test('success', () {
      expect(IO.succeed(1).map((a) => a + 1).runSync(), Exit.right(2));
    });

    test('failure', () {
      expect(
          EIO.fail(1).map((a) => a + 1).runSync(), Exit.left(const Failure(1)));
    });
  });

  group('mapError', () {
    test('success', () {
      expect(EIO.succeed(1).mapError((a) => a + 1).runSync(), Exit.right(1));
    });

    test('failure', () {
      expect(EIO.fail(1).mapError((a) => a + 1).runSync(),
          Exit.left(const Failure(2)));
    });
  });

  group('flatMap', () {
    test('success', () {
      expect(IO.succeed(1).flatMap((a) => ZIO.succeed(a + 1)).runSync(),
          Exit.right(2));
    });

    test('failure', () {
      expect(EIO.fail(1).flatMap((a) => ZIO.succeed(a + 1)).runSync(),
          Exit.left(const Failure(1)));
    });
  });

  group('tapEither', () {
    test('success', () async {
      final deferred = DeferredIO<Either<Never, int>>();
      IO.succeed(1).tapEither(deferred.completeIO).runSyncOrThrow();
      expect(await deferred.awaitIO.runOrThrow(), Either.right(1));
    });

    test('failure', () async {
      final deferred = DeferredIO<Either<int, Never>>();
      EIO<int, Never>.fail(1).tapEither(deferred.completeIO).runSync();
      expect(await deferred.awaitIO.runOrThrow(), Either.left(1));
    });
  });
}
