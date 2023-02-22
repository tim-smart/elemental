import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_elemental/flutter_elemental.dart';

extension ZIOBuildContextExt on BuildContext {
  FutureOr<Exit<E, A>> runZIO<E, A>(
    EIO<E, A> zio, {
    Deferred<Unit>? interrupt,
  }) =>
      registry(listen: false)
          .zioRuntime
          .run(zio, interruptionSignal: interrupt);

  Future<Exit<E, A>> runZIOFuture<E, A>(
    EIO<E, A> zio, {
    Deferred<Unit>? interrupt,
  }) =>
      registry(listen: false)
          .zioRuntime
          .runFuture(zio, interruptionSignal: interrupt);

  Future<A> runZIOFutureOrThrow<E, A>(
    EIO<E, A> zio, {
    Deferred<Unit>? interrupt,
  }) =>
      registry(listen: false)
          .zioRuntime
          .runFutureOrThrow(zio, interruptionSignal: interrupt);

  FutureOr<A> runZIOOrThrow<E, A>(
    EIO<E, A> zio, {
    Deferred<Unit>? interrupt,
  }) =>
      registry(listen: false)
          .zioRuntime
          .runOrThrow(zio, interruptionSignal: interrupt);

  ZIORunner<E, A> makeZIORunner<E, A>(EIO<E, A> zio) =>
      registry(listen: false).zioRuntime.runSyncOrThrow(ZIORunner.make(zio));
}
