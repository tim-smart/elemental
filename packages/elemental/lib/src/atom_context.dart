import 'dart:async';

import 'package:elemental/elemental.dart';

extension ZIOAtomContextExt on AtomContext {
  FutureOr<Exit<E, A>> runZIO<E, A>(
    EIO<E, A> zio, {
    Deferred<Unit>? interrupt,
  }) =>
      registry.get(runtimeAtom).run(zio, interruptionSignal: interrupt);

  Future<Exit<E, A>> runZIOFuture<E, A>(
    EIO<E, A> zio, {
    Deferred<Unit>? interrupt,
  }) =>
      registry.get(runtimeAtom).runFuture(zio, interruptionSignal: interrupt);

  Future<A> runZIOFutureOrThrow<E, A>(
    EIO<E, A> zio, {
    Deferred<Unit>? interrupt,
  }) =>
      registry
          .get(runtimeAtom)
          .runFutureOrThrow(zio, interruptionSignal: interrupt);

  FutureOr<A> runZIOOrThrow<E, A>(
    EIO<E, A> zio, {
    Deferred<Unit>? interrupt,
  }) =>
      registry.get(runtimeAtom).runOrThrow(zio, interruptionSignal: interrupt);

  ZIORunner<E, A> makeZIORunner<E, A>(EIO<E, A> zio) =>
      registry.get(runtimeAtom).runSyncOrThrow(ZIORunner.make(zio));
}
