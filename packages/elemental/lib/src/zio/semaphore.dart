part of '../zio.dart';

class _Waiter extends LinkedListEntry<_Waiter> {
  _Waiter(this.permits);
  final deferred = DeferredIO<Unit>();
  final int permits;
}

/// A semaphore is a concurrency primitive that allows you to limit the number
/// of concurrent operations.
///
/// You can specify the number of permits when creating the semaphore. When you
/// call [take], it will wait until there are enough permits available.
///
/// When you call [release], it will add the number of permits back to the
/// semaphore.
///
/// You can also use [withPermits] to run a [ZIO] with a certain number of
/// permits. It will automatically release the permits when the [ZIO] completes.
class Semaphore {
  Semaphore(this._permits);

  final int _permits;
  int _taken = 0;
  final _waiters = LinkedList<_Waiter>();

  /// Returns the number of permits available.
  int get free => _permits - _taken;

  /// Takes the specified number of permits. If there are not enough permits
  /// available, it will wait until there are.
  ZIO<R, E, Unit> take<R, E>(int permits) => ZIO.from((ctx) {
        if (free >= permits) {
          _taken += _permits;
          return Exit.right(unit);
        }

        final waiter = _Waiter(permits);
        _waiters.add(waiter);
        return waiter.deferred.await()._run(ctx);
      });

  /// Releases the specified number of permits.
  ZIO<R, E, Unit> release<R, E>(int permits) => ZIO(() {
        _taken -= permits;
        if (_waiters.isNotEmpty) {
          final waiter = _waiters.first;
          if (waiter.permits <= free) {
            waiter.unlink();
            waiter.deferred.unsafeCompleteExit(Exit.right(unit));
          }
        }
        return unit;
      });

  /// Runs the specified [ZIO] with the specified number of permits. It will
  /// automatically release the permits when the [ZIO] completes.
  ZIO<R, E, A> withPermits<R, E, A>(int permits, ZIO<R, E, A> zio) =>
      take<R, E>(permits).zipRight(zio).alwaysIgnore(release(permits));
}

/// A [Guarded] is a wrapper around a value that can only be accessed by a
/// by the specified number of [permits] (defaults to 1), at any given time.
class Guarded<A> {
  Guarded(
    this._value, {
    int permits = 1,
  }) : _semaphore = Semaphore(permits);

  final Semaphore _semaphore;
  final A _value;

  ZIO<R, E, B> use<R, E, B>(ZIO<R, E, B> Function(A _) f) =>
      _semaphore.withPermits(1, ZIO.lazy(() => f(_value)));
}
