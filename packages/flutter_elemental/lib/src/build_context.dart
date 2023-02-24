import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_elemental/flutter_elemental.dart';

extension ZIOBuildContextExt on BuildContext {
  FutureOr<Exit<E, A>> runZIO<E, A>(
    EIO<E, A> zio, {
    DeferredIO<Unit>? interrupt,
  }) =>
      registry(listen: false)
          .get(runtimeAtom)
          .run(zio, interruptionSignal: interrupt);

  Future<Exit<E, A>> runZIOFuture<E, A>(
    EIO<E, A> zio, {
    DeferredIO<Unit>? interrupt,
  }) =>
      registry(listen: false)
          .get(runtimeAtom)
          .runFuture(zio, interruptionSignal: interrupt);

  Future<A> runZIOFutureOrThrow<E, A>(
    EIO<E, A> zio, {
    DeferredIO<Unit>? interrupt,
  }) =>
      registry(listen: false)
          .get(runtimeAtom)
          .runFutureOrThrow(zio, interruptionSignal: interrupt);

  FutureOr<A> runZIOOrThrow<E, A>(
    EIO<E, A> zio, {
    DeferredIO<Unit>? interrupt,
  }) =>
      registry(listen: false)
          .get(runtimeAtom)
          .runOrThrow(zio, interruptionSignal: interrupt);

  Exit<E, A> runZIOSync<E, A>(
    EIO<E, A> zio, {
    DeferredIO<Unit>? interrupt,
  }) =>
      registry(listen: false)
          .get(runtimeAtom)
          .runSync(zio, interruptionSignal: interrupt);

  A runZIOSyncOrThrow<E, A>(EIO<E, A> zio) =>
      registry(listen: false).get(runtimeAtom).runSyncOrThrow(zio);

  ZIORunner<E, A> makeZIORunner<E, A>(EIO<E, A> zio) => registry(listen: false)
      .get(runtimeAtom)
      .runSyncOrThrow(ZIORunner.make(zio));
}
