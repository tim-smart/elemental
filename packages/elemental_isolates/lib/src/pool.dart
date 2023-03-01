import 'dart:io';

import 'package:elemental/elemental.dart';
import 'package:elemental_isolates/src/isolate.dart';

ZIO<Scope<NoEnv>, IsolateError, Never> spawnIsolatePool<I, E, O>(
  IsolateHandler<I, E, O> handle, {
  required Dequeue<Request<I, E, O>> requests,
  int? maxSize,
  Schedule<Scope<NoEnv>, IsolateError, IsolateError, dynamic>? respawnSchedule,
}) =>
    ZIO<Scope<NoEnv>, IsolateError, Never>.Do(($, env) async {
      final childCount = Ref.unsafeMake(0);
      final poolSize = maxSize ?? Platform.numberOfProcessors;
      final queue = ZIOQueue<Enqueue<Request<I, E, O>>>.unbounded();
      final exitDeferred = Deferred<IsolateError, Never>();

      final spawnChild =
          ZIO<Scope<NoEnv>, IsolateError, Enqueue<Request<I, E, O>>>.Do(
              ($, env) {
        final childQueue = ZIOQueue<Request<I, E, O>>.unbounded();

        final schedule = respawnSchedule ??
            Schedule.fixed(const Duration(seconds: 1)).lift();
        final fiber =
            $.sync(spawnIsolate(handle, childQueue).retry(schedule).fork());
        fiber.addObserver(exitDeferred.unsafeCompleteExit);

        return $.sync(childCount
            .update<Scope<NoEnv>, IsolateError>((_) => _ + 1)
            .as(childQueue));
      });

      final spawnOffer = spawnChild.flatMap(queue.offer);

      final takeOrSpawn = childCount
          .get<Scope<NoEnv>, IsolateError>()
          .flatMap((_) => _ < poolSize ? spawnChild : queue.take());

      final takeChild =
          queue.poll<Scope<NoEnv>, IsolateError>().flatMap((_) => _.match(
                () => takeOrSpawn,
                ZIO.succeed,
              ));

      final work = requests
          .take<Scope<NoEnv>, IsolateError>()
          .flatMap(
            (request) => takeChild.flatMap(
              (childQueue) => childQueue
                  .offerIO(request)
                  .zipRight(request.second.awaitIO.ignore)
                  .always(queue.offer(childQueue))
                  .forkIO
                  .lift(),
            ),
          )
          .forever;

      await $(spawnOffer.zipRight(work));
    });
