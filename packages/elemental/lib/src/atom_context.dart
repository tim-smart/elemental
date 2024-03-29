import 'dart:async';

import 'package:elemental/elemental.dart';

extension ZIOAtomContextExt on AtomContext {
  /// Calls [Runtime.run] on the [ZIO], using the [Runtime] from [runtimeAtom].
  FutureOr<Exit<E, A>> runZIO<E, A>(
    EIO<E, A> zio, {
    DeferredIO<Never>? interrupt,
  }) =>
      registry.get(runtimeAtom).run(zio, interruptionSignal: interrupt);

  /// Calls [Runtime.runFuture] on the [ZIO], using the [Runtime] from [runtimeAtom].
  Future<Exit<E, A>> runZIOFuture<E, A>(
    EIO<E, A> zio, {
    DeferredIO<Never>? interrupt,
  }) =>
      registry.get(runtimeAtom).runFuture(zio, interruptionSignal: interrupt);

  /// Calls [Runtime.runFutureOrThrow] on the [ZIO], using the [Runtime] from [runtimeAtom].
  Future<A> runZIOFutureOrThrow<E, A>(
    EIO<E, A> zio, {
    DeferredIO<Never>? interrupt,
  }) =>
      registry
          .get(runtimeAtom)
          .runFutureOrThrow(zio, interruptionSignal: interrupt);

  /// Calls [Runtime.runOrThrow] on the [ZIO], using the [Runtime] from [runtimeAtom].
  FutureOr<A> runZIOOrThrow<E, A>(
    EIO<E, A> zio, {
    DeferredIO<Never>? interrupt,
  }) =>
      registry.get(runtimeAtom).runOrThrow(zio, interruptionSignal: interrupt);

  /// Calls [Runtime.runSync] on the [ZIO], using the [Runtime] from [runtimeAtom].
  Exit<E, A> runZIOSync<E, A>(
    EIO<E, A> zio, {
    DeferredIO<Never>? interrupt,
  }) =>
      registry.get(runtimeAtom).runSync(zio, interruptionSignal: interrupt);

  /// Calls [Runtime.runSyncOrThrow] on the [ZIO], using the [Runtime] from [runtimeAtom].
  A runZIOSyncOrThrow<E, A>(EIO<E, A> zio) =>
      registry.get(runtimeAtom).runSyncOrThrow(zio);

  /// Creates a [ZIORunner] for the [ZIO], using the [Runtime] from [runtimeAtom].
  ZIORunner<E, A> makeZIORunner<E, A>(EIO<E, A> zio) =>
      registry.get(runtimeAtom).runSyncOrThrow(ZIORunner.make(zio));
}
