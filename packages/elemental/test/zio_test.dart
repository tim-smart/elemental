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

  group('timeout', () {
    test('success', () {
      expect(
        IO.succeed(1).timeout(const Duration(seconds: 1)).runSyncOrThrow(),
        1,
      );
    });

    test('fail', () async {
      expect(
        await IO
            .succeed(1)
            .delay(const Duration(seconds: 1))
            .timeout(Duration.zero)
            .runFuture(),
        Exit<Never, int>.left(const Interrupted()),
      );
    });
  });

  group('acquireRelease', () {
    test('release is called', () {
      final deferred = DeferredIO<void>();
      IO
          .succeed(1)
          .acquireRelease((_) => deferred.completeIO(null))
          .scoped
          .runSyncOrThrow();
      expect(deferred.unsafeCompleted, true);
    });

    test('defect', () {
      final deferred = DeferredIO<void>();
      IO
          .succeed(1)
          .acquireRelease((_) => deferred.completeIO(null))
          .zipRight(ZIO.die('fail'))
          .scoped
          .runSync();
      expect(deferred.unsafeCompleted, true);
    });
  });

  group('annotations', () {
    test('set and retreive', () {
      const key = Symbol("annotations test");
      final result =
          IO.annotationsIO(key).annotate(key, 'key', 123).runSyncOrThrow();
      expect(result, const IMapConst({'key': 123}));
    });

    test('annotateLog', () {
      final logger = TestLogger();

      IO
          .logInfoIO("hello")
          .annotateLog("key", 123)
          .zipRight(IO.logInfo("world"))
          .provideService(loggerLayer)(logger)
          .runSyncOrThrow();

      expect(logger.items.length, 2);
      expect(logger.items[0].first, "hello");
      expect(logger.items[0].second["key"], 123);

      expect(logger.items[1].first, "world");
      expect(logger.items[1].second.isEmpty, true);
    });
  });
}

class TestLogger implements Logger {
  final items = <Tuple2<String, IMap<String, dynamic>>>[];

  @override
  ZIO<R, E, Unit> log<R, E>(
    LogLevel level,
    DateTime time,
    String message, {
    IMap<String, dynamic> annotations = const IMapConst({}),
  }) =>
      ZIO(() {
        items.add(tuple2(message, annotations));
        return unit;
      });
}
