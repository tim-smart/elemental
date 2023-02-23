part of '../zio.dart';

typedef DeferredIO<A> = Deferred<Never, A>;

class Deferred<E, A> {
  Deferred();

  Deferred.completed(A value) : _value = Option.of(Exit.right(value));
  Deferred.failedCause(Cause<E> cause) : _value = Option.of(Exit.left(cause));
  Deferred.failed(E error) : _value = Option.of(Exit.left(Failure(error)));

  Option<Exit<E, A>> _value = Option.none();

  Completer<Exit<E, A>>? __completer;
  Completer<Exit<E, A>> get _completer =>
      __completer ??= Completer<Exit<E, A>>.sync();

  IO<bool> get completed => IO(_value.isSome);
  bool get unsafeCompleted => _value.isSome();

  ZIO<R, E2, Exit<E, A>> awaitExit<R, E2>() => ZIO.from(
        (ctx) => _value.match(
          () => _completer.future.then(Exit.right),
          (_) => Exit.right(_),
        ),
      );
  late final IO<Exit<E, A>> awaitExitIO = awaitExit();

  ZIO<R, E, A> await<R>() => ZIO.from(
        (ctx) => _value.match(
          () => _completer.future,
          identity,
        ),
      );
  late final EIO<E, A> awaitIO = await();

  void unsafeCompleteExit(Exit<E, A> exit) {
    _value = Option.of(exit);
    __completer?.complete(exit);
  }

  ZIO<R, E2, Unit> completeExit<R, E2>(Exit<E, A> exit) =>
      ZIO(() => _value.match(
            () {
              unsafeCompleteExit(exit);
              return unit;
            },
            (_) => unit,
          ));

  ZIO<R, E2, Unit> complete<R, E2>(A value) => completeExit(Exit.right(value));
  IO<Unit> completeIO(A value) => complete(value);

  ZIO<R, E2, Unit> failCause<R, E2>(Cause<E> cause) =>
      completeExit(Exit.left(cause));
  IO<Unit> failCauseIO(Cause<E> cause) => failCause(cause);

  ZIO<R, E2, Unit> fail<R, E2>(E error) => failCause(Failure(error));
  IO<Unit> failIO(E error) => fail(error);
}
