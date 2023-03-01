import 'package:elemental/elemental.dart';
import 'package:elemental_isolates/src/isolate.dart';
import 'package:elemental_isolates/src/pool.dart';
import 'package:test/test.dart';

void main() {
  group('spawnPool', () {
    test('works', () async {
      final requests =
          ZIOQueue<Tuple2<int, Deferred<Never, String>>>.unbounded();

      final deferred1 = DeferredIO<String>();
      requests.offerIO(tuple2(1, deferred1)).run();
      final deferred2 = DeferredIO<String>();
      requests.offerIO(tuple2(2, deferred2)).run();
      final deferred3 = DeferredIO<String>();
      requests.offerIO(tuple2(3, deferred3)).run();

      await spawnIsolatePool(
        (count) => ZIO.succeed("Got: $count"),
        requests: requests,
        size: 3,
      )
          .asUnit
          .scoped
          .race(deferred3.awaitIO.lift<NoEnv, IsolateError>().asUnit)
          .runOrThrow();

      expect(deferred1.awaitIO.runSyncOrThrow(), "Got: 1");
      expect(deferred2.awaitIO.runSyncOrThrow(), "Got: 2");
      expect(deferred3.awaitIO.runSyncOrThrow(), "Got: 3");
    });
  });
}
