import 'package:elemental/elemental.dart';
import 'package:elemental_isolates/elemental_isolates.dart';

class ZIOIsolateRunner {
  const ZIOIsolateRunner(this.requests);

  final Enqueue<Request<EIO, dynamic, dynamic>> requests;

  ZIO<R, E, A> run<R, E, A>(ZIO<R, E, A> zio) => ZIO.from((ctx) {
        final deferred = Deferred<dynamic, dynamic>();
        return requests
            .offer<NoEnv, dynamic>(tuple2(
              zio.mapError((_) => _ as dynamic).provide(ctx.env),
              deferred,
            ))
            .zipRight(deferred.awaitIO)
            .mapError((_) => _ as E)
            .map((_) => _ as A)
            .unsafeRun(ctx.noEnv);
      });
}

final zioIsolateRunnerLayer = Layer<Never, ZIOIsolateRunner>.scoped(
  ZIO.Do(($, env) {
    final requests = $.sync(
      ZIOQueue.unboundedScope<Request<EIO, dynamic, dynamic>>(),
    );

    $.sync(spawnIsolatePool<EIO, dynamic, dynamic>(
      (_) => _,
      requests: requests,
    ).tapError(ZIO.logError).forkScope());

    return ZIOIsolateRunner(requests);
  }),
);

extension ZIOIsolateExt<R, E, A> on ZIO<R, E, A> {
  ZIO<R, E, A> get onIsolate =>
      zioIsolateRunnerLayer.access.lift<R, E>().flatMap((_) => _.run(this));
}
