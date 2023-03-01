import 'package:elemental/elemental.dart';
import 'package:elemental_isolates/src/isolate.dart';
import 'package:elemental_isolates/src/pool.dart';

class ZIOIsolateRunner {
  const ZIOIsolateRunner(this.requests);

  final Enqueue<Request<EIO, dynamic, dynamic>> requests;

  ZIO<R, E, A> run<R, E, A>(ZIO<R, E, A> zio) => ZIO.from((ctx) {
        final deferred = Deferred<E, A>();
        return requests
            .offer<NoEnv, E>(tuple2(zio.provide(ctx.env), deferred))
            .zipRight(deferred.await())
            .unsafeRun(ctx.noEnv);
      });
}

final zioIsolateRunnerLayer = Layer<Never, ZIOIsolateRunner>.scoped(
  ZIO.Do(($, env) {
    final requests = ZIOQueue<Request<EIO, dynamic, dynamic>>.unbounded();

    $.sync(spawnIsolatePool<EIO, dynamic, dynamic>(
      (_) => _,
      requests: requests,
    ).ignoreLogged.fork());

    return ZIOIsolateRunner(requests);
  }),
);
