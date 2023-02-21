import 'dart:async';

import 'package:elemental/elemental.dart';

FutureOr<B> fromThrowable<A, B>(
  FutureOr<A> Function() f, {
  required B Function(A a) onSuccess,
  required B Function(dynamic error, StackTrace stackTrace) onError,
  required Deferred<Unit> interruptionSignal,
}) {
  if (interruptionSignal.unsafeCompleted) {
    throw Interrupted();
  }

  try {
    final a = f();
    if (a is Future) {
      return (a as Future<A>).then((_) {
        if (interruptionSignal.unsafeCompleted) {
          throw Interrupted();
        }
        return onSuccess(_);
      }, onError: onError);
    }
    return onSuccess(a);
  } catch (err, stack) {
    return onError(err, stack);
  }
}

extension FlatMapExtension<A> on FutureOr<A> {
  FutureOr<B> flatMapFOr<B>(
    FutureOr<B> Function(A a) f, {
    required Deferred<Unit> interruptionSignal,
  }) {
    if (interruptionSignal.unsafeCompleted) {
      throw Interrupted();
    }

    if (this is Future) {
      return (this as Future<A>).then((_) {
        if (interruptionSignal.unsafeCompleted) {
          throw Interrupted();
        }

        return f(_);
      });
    }

    return f(this as A);
  }
}
