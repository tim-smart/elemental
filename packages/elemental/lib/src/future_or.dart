import 'dart:async';

FutureOr<B> fromThrowable<A, B>(
  FutureOr<A> Function() f, {
  required B Function(A a) onSuccess,
  required B Function(dynamic error, StackTrace stackTrace) onError,
}) {
  try {
    final a = f();
    if (a is Future) {
      return (a as Future<A>).then(onSuccess, onError: onError);
    }
    return onSuccess(a);
  } catch (err, stack) {
    return onError(err, stack);
  }
}

extension FlatMapExtension<A> on FutureOr<A> {
  FutureOr<B> flatMapFOr<B>(FutureOr<B> Function(A a) f) {
    if (this is Future) {
      return (this as Future<A>).then(f);
    }

    return f(this as A);
  }

  FutureOr<B> flatMapThrowable<B>(
    FutureOr<B> Function(A a) f,
    B Function(dynamic error, StackTrace stackTrace) onError,
  ) {
    if (this is Future) {
      return (this as Future<A>).then(f, onError: onError);
    } else {
      try {
        return f(this as A);
      } catch (err, stack) {
        return onError(err, stack);
      }
    }
  }
}
