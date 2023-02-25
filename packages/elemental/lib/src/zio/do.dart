part of '../zio.dart';

/// A function that can be used in a [ZIO.Do].
typedef DoFunction<R, E, A> = FutureOr<A> Function(
  // ignore: library_private_types_in_public_api
  DoContext<R, E> $,
  R env,
);

class DoContext<R, E> {
  DoContext(this._ctx);

  final ZIOContext<R> _ctx;

  FutureOr<A> call<A>(ZIO<R, E, A> zio) => zio._run(_ctx).then(
        (ea) => ea.match(
          (e) => throw e,
          identity,
        ),
      );

  A sync<A>(ZIO<R, E, A> zio) {
    final result = call(zio);

    if (result is Future) {
      throw Defect<E>(
        "DoContext.sync() called with async ZIO",
        StackTrace.current,
      );
    }

    return result;
  }
}
