import 'dart:io';

import 'package:elemental/elemental.dart';
import 'package:elemental_isolates/src/isolate.dart';

ZIO<Scope<NoEnv>, IsolateError, Never> spawnIsolatePool<I, E, O>(
  IsolateHandler<I, E, O> handle, {
  required Dequeue<Request<I, E, O>> requests,
  int? size,
  Schedule<Scope<NoEnv>, IsolateError, IsolateError, dynamic>? respawnSchedule,
}) =>
    ZIO<Scope<NoEnv>, IsolateError, Never>.Do(($, env) async {
      final poolSize = size ?? Platform.numberOfProcessors;
      final queue = ZIOQueue<Enqueue<Request<I, E, O>>>.unbounded();

      final spawnChild = ZIO.lazy(() {
        final childQueue = ZIOQueue<Request<I, E, O>>.unbounded();

        final schedule = respawnSchedule ??
            Schedule.fixed(const Duration(seconds: 1)).lift();
        final spawnRetry = spawnIsolate(handle, childQueue).retry(schedule);

        return queue
            .offer<Scope<NoEnv>, IsolateError>(childQueue)
            .zipRight(spawnRetry);
      });

      final work = requests.takeIO
          .flatMap(
            (request) => queue.takeIO.flatMap(
              (childQueue) => childQueue
                  .offerIO(request)
                  .zipRight(request.second.awaitIO.ignore)
                  .always(queue.offer(childQueue)),
            ),
          )
          .forever;

      final children = List.generate(poolSize, (index) => spawnChild);
      children.add(work.lift());
      await $(children.raceAll);
    });
