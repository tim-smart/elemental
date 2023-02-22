import 'dart:async';

import 'package:elemental/elemental.dart';

FutureOr<Exit<E, A>> fromThrowableNoI<E, A>(
  FutureOr<A> Function() f, {
  required Cause<E> Function(dynamic error, StackTrace stack) onError,
  Deferred<Unit>? interruptionSignal,
}) {
  if (interruptionSignal?.unsafeCompleted == true) {
    throw Interrupted();
  }

  try {
    final a = f();
    if (a is Future) {
      return (a as Future<A>).then(
        (_) {
          if (interruptionSignal?.unsafeCompleted == true) {
            throw Interrupted();
          }
          return Either.right(_);
        },
        onError: (err, stack) {
          try {
            return Either.left(onError(err, stack));
          } catch (err, stack) {
            return Either.left(Defect(err, stack));
          }
        },
      );
    }
    return Either.right(a);
  } catch (err, stack) {
    try {
      return Either.left(onError(err, stack));
    } catch (err, stack) {
      return Either.left(Defect(err, stack));
    }
  }
}

FutureOr<Exit<E, A>> fromThrowable<E, A>(
  FutureOr<A> Function() f, {
  required Cause<E> Function(dynamic error, StackTrace stack) onError,
  required Deferred<Unit> interruptionSignal,
}) =>
    fromThrowableNoI(
      f,
      onError: onError,
      interruptionSignal: interruptionSignal,
    );

extension FlatMapExtension<A> on FutureOr<A> {
  FutureOr<B> flatMapFOrNoI<B>(FutureOr<B> Function(A exit) f) {
    if (this is Future) {
      return (this as Future<A>).then(f);
    }
    return f(this as A);
  }

  FutureOr<B> flatMapFOr<B>(
    FutureOr<B> Function(A exit) f, {
    required Deferred<Unit> interruptionSignal,
  }) {
    if (interruptionSignal.unsafeCompleted == true) {
      throw Interrupted();
    }

    if (this is Future) {
      return (this as Future<A>).then((_) {
        if (interruptionSignal.unsafeCompleted == true) {
          throw Interrupted();
        }

        return f(_);
      });
    }

    return f(this as A);
  }
}
