import 'package:elemental/elemental.dart';
import 'package:elemental_isolates/src/isolate.dart';
import 'package:test/test.dart';

void main() {
  group('spawn', () {
    test('works', () async {
      final deferred = DeferredIO<String>();
      final requests = ZIOQueue<(int, Deferred<Never, String>)>.unbounded();

      requests.offerIO((123, deferred)).run();

      await spawnIsolate((int count) => ZIO.succeed("Got: $count"), requests)
          .asUnit
          .scoped
          .race(deferred.awaitIO.lift<NoEnv, IsolateError>().asUnit)
          .run();

      expect(deferred.awaitIO.runSyncOrThrow(), "Got: 123");
    });

    test('send zio', () async {
      final deferred = DeferredIO<String>();
      final requests =
          ZIOQueue<(IO<String>, Deferred<Never, String>)>.unbounded();

      requests.offerIO((IO.succeed("abc"), deferred)).run();

      await spawnIsolate((IO<String> _) => _, requests)
          .asUnit
          .scoped
          .race(deferred.awaitIO.lift<NoEnv, IsolateError>().asUnit)
          .runOrThrow();

      expect(deferred.awaitIO.runSyncOrThrow(), "abc");
    });
  });
}
