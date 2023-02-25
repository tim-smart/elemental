part of '../zio.dart';

class AsyncContext<E, A> {
  final _deferred = Deferred<E, A>();

  void succeed(A value) => _deferred.unsafeCompleteExit(Exit.right(value));

  void fail(E error) => _deferred.unsafeCompleteExit(Exit.left(Failure(error)));

  void failCause(Cause<E> cause) =>
      _deferred.unsafeCompleteExit(Exit.left(cause));

  void die(dynamic defect) => _deferred
      .unsafeCompleteExit(Exit.left(Defect(defect, StackTrace.current)));
}
