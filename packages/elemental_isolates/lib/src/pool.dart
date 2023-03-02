import 'dart:io';

import 'package:elemental/elemental.dart';
import 'package:elemental_isolates/elemental_isolates.dart';

ZIO<Scope<NoEnv>, IsolateError, Never> spawnIsolatePool<I, E, O>(
  IsolateHandler<I, E, O> handle, {
  required Dequeue<Request<I, E, O>> requests,
  int? maxSize,
  Schedule<Scope<NoEnv>, IsolateError, IsolateError, dynamic>? respawnSchedule,
}) =>
    ZIO<Scope<NoEnv>, IsolateError, Never>.Do(($, env) async {
      final exitDeferred = Deferred<IsolateError, Never>();
      final poolSize = maxSize ?? Platform.numberOfProcessors;

      RIO<Scope<NoEnv>, IsolatePoolChild<I, E, O>> spawnChild(int id) =>
          ZIO.Do(($, env) {
            final child = IsolatePoolChild<I, E, O>.empty(
              id,
              $.sync(ZIOQueue.unboundedScope()),
            );

            final schedule = respawnSchedule ??
                Schedule.fixed(const Duration(seconds: 1)).lift();
            $
                .sync(spawnIsolate(handle, child.queue).retry(schedule).fork())
                .addObserver(exitDeferred.unsafeCompleteExit);

            return child;
          });

      final children = Ref.unsafeMake(
        ISet<IsolatePoolChild<I, E, O>>.withConfig(
          $.sync(List.generate(poolSize, (id) => spawnChild(id)).collect),
          ConfigSet(sort: true),
        ),
      );

      final work = requests.takeIO
          .flatMap(
            (request) => children
                .unsafeGet()
                .first
                .offer(request)
                .flatMap((child) => children
                    .updateIO((_) => _.replace(child))
                    .zipRight(request.second.awaitIO.ignore)
                    .alwaysIgnore(children.updateIO(
                      (_) => _.replace(_.find(child).addProcessed()),
                    ))
                    .lift())
                .forkIO,
          )
          .forever
          .lift<Scope<NoEnv>, IsolateError>();

      await $(work.race(exitDeferred.awaitIO.lift()));
    });

class IsolatePoolChild<I, E, O>
    implements Comparable<IsolatePoolChild<I, E, O>> {
  IsolatePoolChild({
    required this.id,
    required this.processed,
    required this.active,
    required this.queue,
    DateTime? lastActive,
  }) : lastActive = lastActive ?? DateTime.now();

  factory IsolatePoolChild.empty(
    int id,
    ZIOQueue<Request<I, E, O>> queue,
  ) =>
      IsolatePoolChild(
        id: id,
        processed: 0,
        active: 0,
        queue: queue,
      );

  final int id;
  final int processed;
  final int active;
  final DateTime lastActive;
  final ZIOQueue<Request<I, E, O>> queue;

  @override
  int compareTo(IsolatePoolChild<I, E, O> other) {
    if (other.active == active) {
      return lastActive.compareTo(other.lastActive);
    }
    return (other.active > active) ? -1 : 1;
  }

  IO<IsolatePoolChild<I, E, O>> offer(
    Request<I, E, O> request,
  ) =>
      queue.offerIO(request).as(addActive());

  IsolatePoolChild<I, E, O> addActive() => copyWith(
        active: active + 1,
        lastActive: DateTime.now(),
      );

  IsolatePoolChild<I, E, O> addProcessed() => copyWith(
        processed: processed + 1,
        active: active - 1,
      );

  IsolatePoolChild<I, E, O> copyWith({
    int? processed,
    int? active,
    DateTime? lastActive,
  }) =>
      IsolatePoolChild(
        id: id,
        queue: queue,
        processed: processed ?? this.processed,
        active: active ?? this.active,
        lastActive: lastActive ?? this.lastActive,
      );

  @override
  bool operator ==(Object other) => other is IsolatePoolChild && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'IsolatePoolChild<$I, $E, $O>(id: $id, processed: $processed, active: $active, lastActive: $lastActive)';
}

extension _ISetReplace<A> on ISet<A> {
  A find(A item) => firstWhere((_) => _ == item);

  ISet<A> replace(A item) => remove(item).add(item);
}
