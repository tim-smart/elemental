import 'dart:async';

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

  group('asyncInterrupt', () {
    test('finalizer is called', () async {
      final deferred = DeferredIO<Unit>();
      final zio = IO<Never>.asyncInterrupt((cb) {
        return deferred.completeIO(unit);
      });
      final fiber = zio.fork().runSyncOrThrow();
      fiber.interruptIO.runFutureOrThrow();
      expect(deferred.unsafeCompleted, true);
    });

    test('finalizer is not called once returned', () async {
      final deferred = DeferredIO<Unit>();
      final zio = IO<Unit>.asyncInterrupt((resume) {
        resume.succeed(unit);
        return deferred.completeIO(unit);
      });
      final fiber = zio.fork().runSyncOrThrow();
      fiber.interruptIO.runFutureOrThrow();
      expect(deferred.unsafeCompleted, false);
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
      expect(logger.items[0].$1, "hello");
      expect(logger.items[0].$2["key"], 123);

      expect(logger.items[1].$1, "world");
      expect(logger.items[1].$2.isEmpty, true);
    });
  });

  group('collectPar', () {
    test('collects results in parallel', () async {
      final c = Completer<IList<int>>();
      [
        IO.succeed(1),
        IO.succeed(2).delay(const Duration(milliseconds: 10)),
        IO.succeed(3).delay(const Duration(milliseconds: 20)),
      ].collectPar.runFutureOrThrow().then(c.complete);

      await Future.delayed(const Duration(milliseconds: 25));

      expect(c.isCompleted, true);
      expect(await c.future, const IListConst([1, 2, 3]));
    });

    test('failure interrupts', () async {
      final c = Completer<Exit<Never, IList<int>>>();
      [
        IO.succeed(1),
        IO<int>.die("fail").delay(const Duration(milliseconds: 10)),
        IO.succeed(3).delay(const Duration(milliseconds: 20)),
      ].collectPar.runFuture().then(c.complete);

      await Future.delayed(const Duration(milliseconds: 15));

      expect(c.isCompleted, true);
      expect(
        await c.future,
        Exit<Never, IList<int>>.left(Defect.current("fail")),
      );
    });
  });
}

class TestLogger implements Logger {
  final items = <(String, IMap<String, dynamic>)>[];

  @override
  ZIO<R, E, Unit> log<R, E>(
    LogLevel level,
    DateTime time,
    String message, {
    IMap<String, dynamic> annotations = const IMapConst({}),
  }) =>
      ZIO(() {
        items.add((message, annotations));
        return unit;
      });
}
