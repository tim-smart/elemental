import 'package:elemental/elemental.dart';
import 'package:elemental_isolates/elemental_isolates.dart';
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

      final fiber = spawnIsolatePool(
        (count) => ZIO.succeed("Got: $count"),
        requests: requests,
      ).asUnit.scoped.fork().runSyncOrThrow();

      expect(await deferred1.awaitIO.runOrThrow(), "Got: 1");
      expect(await deferred2.awaitIO.runOrThrow(), "Got: 2");
      expect(await deferred3.awaitIO.runOrThrow(), "Got: 3");

      fiber.interruptIO.runSyncOrThrow();
    });
  });
}
