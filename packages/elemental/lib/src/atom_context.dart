import 'dart:async';

import 'package:elemental/elemental.dart';

extension ZIOAtomContextExt on AtomContext {
  /// Calls [Runtime.run] on the [ZIO], using the [Runtime] from [runtimeAtom].
  FutureOr<Exit<E, A>> runZIO<E, A>(
    EIO<E, A> zio, {
    DeferredIO<Unit>? interrupt,
  }) =>
      registry.get(runtimeAtom).run(zio, interruptionSignal: interrupt);

  /// Calls [Runtime.runFuture] on the [ZIO], using the [Runtime] from [runtimeAtom].
  Future<Exit<E, A>> runZIOFuture<E, A>(
    EIO<E, A> zio, {
    DeferredIO<Unit>? interrupt,
  }) =>
      registry.get(runtimeAtom).runFuture(zio, interruptionSignal: interrupt);

  /// Calls [Runtime.runFutureOrThrow] on the [ZIO], using the [Runtime] from [runtimeAtom].
  Future<A> runZIOFutureOrThrow<E, A>(
    EIO<E, A> zio, {
    DeferredIO<Unit>? interrupt,
  }) =>
      registry
          .get(runtimeAtom)
          .runFutureOrThrow(zio, interruptionSignal: interrupt);

  /// Calls [Runtime.runOrThrow] on the [ZIO], using the [Runtime] from [runtimeAtom].
  FutureOr<A> runZIOOrThrow<E, A>(
    EIO<E, A> zio, {
    DeferredIO<Unit>? interrupt,
  }) =>
      registry.get(runtimeAtom).runOrThrow(zio, interruptionSignal: interrupt);

  /// Creates a [ZIORunner] for the [ZIO], using the [Runtime] from [runtimeAtom].
  ZIORunner<E, A> makeZIORunner<E, A>(EIO<E, A> zio) =>
      registry.get(runtimeAtom).runSyncOrThrow(ZIORunner.make(zio));
}
