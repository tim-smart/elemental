part of '../zio.dart';

class _Taker<A> {
  _Taker();

  final deferred = DeferredIO<A>();
  _Taker<A>? next;
}

/// An asynchronous queue. It is backed by a [ListQueue] and a linked list of [DeferredIO]s.
///
/// You can [take] items from the queue, [offer] items onto the queue, [takeAll] from the queue.
///
/// Calling [shutdown] will interrupt all pending [take]s.
class ZIOQueue<A> {
  ZIOQueue.unbounded();

  final _buffer = ListQueue<A>();
  _Taker<A>? _takers;

  /// Returns whether the queue is empty.
  ZIO<R, E, bool> isEmpty<R, E>() => ZIO(() => _buffer.isEmpty);

  /// [IO] version of [isEmpty].
  IO<bool> get isEmptyIO => isEmpty();

  /// Offers an item to the queue. If there are pending [take]s, it will complete the first one.
  ZIO<R, E, Unit> offer<R, E>(A value) => ZIO(() {
        if (_takers != null) {
          final taker = _takers!;
          _takers = taker.next;
          taker.deferred.unsafeCompleteExit(Exit.right(value));
        } else {
          _buffer.add(value);
        }

        return unit;
      });

  /// [IO] version of [offer].
  IO<Unit> offerIO(A value) => offer(value);

  /// Takes an item from the queue. If the queue is empty, it will wait until an item is available.
  ZIO<R, E, A> take<R, E>() => ZIO.from((ctx) {
        if (_buffer.isNotEmpty) {
          return Exit.right(_buffer.removeFirst());
        }

        final taker = _Taker<A>();
        if (_takers == null) {
          _takers = taker;
        } else {
          _takers!.next = taker;
        }

        return taker.deferred.await()._run(ctx);
      });

  /// [IO] version of [take].
  IO<A> get takeIO => take();

  /// Takes all items from the queue, returning an empty list if the queue is empty.
  ZIO<R, E, IList<A>> takeAll<R, E>() => ZIO(() {
        if (_buffer.isEmpty) return IList();

        final list = _buffer.toIList();
        _buffer.clear();
        return list;
      });

  /// [IO] version of [takeAll].
  IO<IList<A>> get takeAllIO => takeAll();

  /// Polls the queue for a value. If the queue is empty, it will return [none].
  ZIO<R, E, Option<A>> poll<R, E>() => ZIO(() {
        if (_buffer.isNotEmpty) {
          return some(_buffer.removeFirst());
        }

        return none();
      });

  /// [IO] version of [poll].
  IO<Option<A>> get pollIO => poll();

  /// Interrupts all pending [take]s.
  ZIO<R, E, Unit> shutdown<R, E>() => ZIO.from((ctx) {
        _buffer.clear();
        if (_takers == null) return Exit.right(unit);

        final List<ZIO<R, E, Unit>> zios = [];
        var taker = _takers;
        while (taker != null) {
          zios.add(taker.deferred.failCause(const Interrupted()));
          taker = taker.next;
        }

        return zios.collectParDiscard._run(ctx);
      });

  /// [IO] version of [shutdown].
  IO<Unit> get shutdownIO => shutdown();
}
