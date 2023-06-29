part of '../zio.dart';

final class _Taker<A> extends LinkedListEntry<_Taker<A>> {
  final deferred = DeferredIO<A>();
}

abstract class Enqueue<A> {
  /// Offers an item to the queue. If there are pending [take]s, it will complete the first one.
  ZIO<R, E, Unit> offer<R, E>(A value);

  /// [IO] version of [offer].
  IO<Unit> offerIO(A value);

  /// Interrupts all pending [take]s.
  ZIO<R, E, Unit> shutdown<R, E>();

  /// [IO] version of [shutdown].
  IO<Unit> get shutdownIO;
}

abstract class Dequeue<A> {
  /// Returns whether the queue is empty.
  ZIO<R, E, bool> isEmpty<R, E>();

  /// [IO] version of [isEmpty].
  IO<bool> get isEmptyIO;

  /// Takes an item from the queue. If the queue is empty, it will wait until an item is available.
  ZIO<R, E, A> take<R, E>();

  /// [IO] version of [take].
  IO<A> get takeIO;

  /// Takes all items from the queue, returning an empty list if the queue is empty.
  ZIO<R, E, IList<A>> takeAll<R, E>();

  /// [IO] version of [takeAll].
  IO<IList<A>> get takeAllIO;

  /// Polls the queue for a value. If the queue is empty, it will return [none].
  ZIO<R, E, Option<A>> poll<R, E>();

  /// [IO] version of [poll].
  IO<Option<A>> get pollIO;
}

/// An asynchronous queue. It is backed by a [ListQueue] and a linked list of [DeferredIO]s.
///
/// You can [take] items from the queue, [offer] items onto the queue, [takeAll] from the queue.
///
/// Calling [shutdown] will interrupt all pending [take]s.
class ZIOQueue<A> implements Dequeue<A>, Enqueue<A> {
  ZIOQueue.unbounded();

  static RIO<Scope<NoEnv>, ZIOQueue<A>> unboundedScope<A>() =>
      IO(ZIOQueue<A>.unbounded).acquireRelease((_) => _.shutdownIO);

  final _buffer = ListQueue<A>();
  final _takers = LinkedList<_Taker<A>>();

  @override
  ZIO<R, E, bool> isEmpty<R, E>() => ZIO(() => _buffer.isEmpty);

  @override
  IO<bool> get isEmptyIO => isEmpty();

  @override
  ZIO<R, E, Unit> offer<R, E>(A value) => ZIO(() {
        if (_takers.isEmpty) {
          _buffer.add(value);
        } else {
          (_takers.first..unlink())
              .deferred
              .unsafeCompleteExit(Exit.right(value));
        }

        return unit;
      });

  @override
  IO<Unit> offerIO(A value) => offer(value);

  @override
  ZIO<R, E, A> take<R, E>() => ZIO.from((ctx) {
        if (_buffer.isNotEmpty) {
          return Exit.right(_buffer.removeFirst());
        }

        final taker = _Taker<A>();
        _takers.add(taker);
        return taker.deferred.await().unsafeRun(ctx);
      });

  @override
  IO<A> get takeIO => take();

  @override
  ZIO<R, E, IList<A>> takeAll<R, E>() => ZIO(() {
        if (_buffer.isEmpty) return IList();

        final list = _buffer.toIList();
        _buffer.clear();
        return list;
      });

  @override
  IO<IList<A>> get takeAllIO => takeAll();

  @override
  ZIO<R, E, Option<A>> poll<R, E>() => ZIO(() {
        if (_buffer.isNotEmpty) {
          return some(_buffer.removeFirst());
        }

        return none();
      });

  @override
  IO<Option<A>> get pollIO => poll();

  @override
  ZIO<R, E, Unit> shutdown<R, E>() => ZIO.from((ctx) {
        _buffer.clear();
        if (_takers.isEmpty) return Exit.right(unit);

        return _takers
            .map((_) => _.deferred.failCause<R, E>(const Interrupted()))
            .collectParDiscard
            .zipLeft(ZIO(_takers.clear))
            .unsafeRun(ctx);
      });

  @override
  IO<Unit> get shutdownIO => shutdown();
}
