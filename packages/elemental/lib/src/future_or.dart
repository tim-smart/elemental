import 'dart:async';

import 'package:elemental/elemental.dart';

FutureOr<Exit<E, A>> fromThrowable<E, A>(
  FutureOr<A> Function() f, {
  required Cause<E> Function(dynamic error, StackTrace stack) onError,
}) {
  try {
    final a = f();
    if (a is Future) {
      return (a as Future<A>).then(
        Either.right,
        onError: (err, stack) {
          try {
            return Exit<E, A>.left(onError(err, stack));
          } catch (err, stack) {
            return Exit<E, A>.left(Defect(err, stack));
          }
        },
      );
    }
    return Either.right(a);
  } catch (err, stack) {
    try {
      return Exit<E, A>.left(onError(err, stack));
    } catch (err, stack) {
      return Exit<E, A>.left(Defect(err, stack));
    }
  }
}

extension FutureOrThenExtension<A> on FutureOr<A> {
  FutureOr<B> then<B>(FutureOr<B> Function(A a) f) {
    if (this is Future) {
      return (this as Future<A>).then(f);
    }
    return f(this as A);
  }
}
