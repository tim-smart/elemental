import 'package:elemental/elemental.dart';
import 'package:elemental_isolates/src/isolate.dart';
import 'package:elemental_isolates/src/pool.dart';

class IsolateFiber<R, E, A> extends Fiber<R, E, A> {
  IsolateFiber(this._zio);

  final ZIO<R, E, A> _zio;
  final _exit = Deferred<E, A>();

  final _observers = <void Function(Exit<E, A>)>{};

  @override
  void Function() addObserver(void Function(Exit<E, A> exit) observer) {
    if (_exit.unsafeCompleted) {
      observer(_exit.awaitIO.runSync());
      return () {};
    }
    _observers.add(observer);
    return () => _observers.remove(observer);
  }

  @override
  ZIO<R2, E, A> join<R2>() => _exit.await();

  // === run
  late final _run = _zio.tapExit(
    (exit) => _exit.completeExit<R, E>(exit).zipLeft(ZIO(() {
      for (final observer in _observers) {
        observer(exit);
      }
      _observers.clear();
    })),
  );

  @override
  ZIO<R, E2, Unit> run<E2>() => zioIsolatePoolLayer.access
      .lift<R, E2>()
      .flatMap((pool) => ZIO.from((ctx) {
            pool.run(_run).unsafeRun(ctx);
            return Exit.right(unit);
          }));
}

class IsolateFiberPool {
  const IsolateFiberPool(this.requests);

  final Enqueue<Request<EIO, dynamic, dynamic>> requests;

  ZIO<R, E, A> run<R, E, A>(ZIO<R, E, A> zio) => ZIO.from((ctx) {
        final deferred = Deferred<E, A>();
        return requests
            .offer<NoEnv, E>(tuple2(zio.provide(ctx.env), deferred))
            .zipRight(deferred.await())
            .unsafeRun(ctx.noEnv);
      });
}

final zioIsolatePoolLayer = Layer<Never, IsolateFiberPool>.scoped(
  ZIO.Do(($, env) {
    final requests = ZIOQueue<Request<EIO, dynamic, dynamic>>.unbounded();

    $.sync(spawnIsolatePool<EIO, dynamic, dynamic>(
      identity,
      requests: requests,
    ).ignoreLogged.fork());

    return IsolateFiberPool(requests);
  }),
);
