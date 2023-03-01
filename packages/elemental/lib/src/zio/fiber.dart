part of '../zio.dart';

/// While elemental does not have a fiber runtime, [Fiber] is used to abstract
/// the running of [ZIO]'s in the background.
abstract class Fiber<R, E, A> {
  /// Allows you to observe the exit of the fiber.
  ///
  /// If the [ZIO] runs synchronously, the [observer] will be called
  /// immediately.
  void Function() addObserver(void Function(Exit<E, A> exit) observer);

  /// Allows you to re-join the fiber and get the result of the [ZIO] that this
  /// fiber is running.
  ZIO<R2, E, A> join<R2>();

  /// An [EIO] version of [join].
  EIO<E, A> get joinIO => join();

  /// Run the fiber in the background.
  ZIO<R, E2, Unit> run<E2>();

  /// An [RIO] version of [run].
  RIO<R, Unit> get runIO => run();

  /// Interrupt the fiber.
  ZIO<R2, E2, Unit> interrupt<R2, E2>();

  /// An [RIO] version of [interrupt].
  IO<Unit> get interruptIO => interrupt();
}

class _DeferredFiber<R, E, A> extends Fiber<R, E, A> {
  _DeferredFiber(this._zio);

  final ZIO<R, E, A> _zio;
  final _exit = Deferred<E, A>();
  final _signal = DeferredIO<Never>();

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
  ZIO<R, E2, Unit> run<E2>() => ZIO.from((ctx) {
        ctx.runtime.run(_run.provide(ctx.env).race(_signal.await()),
            interruptionSignal: ctx.signal);
        return Exit.right(unit);
      });

  @override
  ZIO<R2, E2, Unit> interrupt<R2, E2>() =>
      _signal.failCause(const Interrupted());
}
