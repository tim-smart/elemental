import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_elemental/flutter_elemental.dart';

/// A [ZIO] that requires a [BuildContext] to run.
typedef BuildContextEIO<E, A> = ZIO<BuildContext, E, A>;

/// A [ZIO] that requires a [BuildContext] to run, and never fails.
typedef BuildContextIO<A> = ZIO<BuildContext, Never, A>;

/// A [ZIO] that requires a [BuildContext] to run, and has an optional value.
typedef BuildContextIOOption<A> = RIOOption<BuildContext, A>;

extension ZIOBuildContextRunExt<E, A> on EIO<E, A> {
  /// Runs this [ZIO] asynchronously or synchronously as a [FutureOr], returning the [Exit] result.
  FutureOr<Exit<E, A>> runWith(
    BuildContext context, {
    DeferredIO<Never>? interruptionSignal,
  }) =>
      context.registry(listen: false).get(runtimeAtom).run(
            this,
            interruptionSignal: interruptionSignal,
          );

  /// Runs this [ZIO] asynchronously and returns result as a [Future]. If the [ZIO] fails, the [Future] will throw.
  Future<A> runFutureOrThrowWith(
    BuildContext context, {
    DeferredIO<Never>? interruptionSignal,
  }) =>
      context.registry(listen: false).get(runtimeAtom).runFutureOrThrow(
            this,
            interruptionSignal: interruptionSignal,
          );

  /// Runs this [ZIO] asynchronously and returns the [Exit] result as a [Future].
  Future<Exit<E, A>> runFutureWith(
    BuildContext context, {
    DeferredIO<Never>? interruptionSignal,
  }) =>
      context.registry(listen: false).get(runtimeAtom).runFuture(
            this,
            interruptionSignal: interruptionSignal,
          );

  /// Runs this [ZIO] synchronously or asynchronously as a [FutureOr], throwing if it fails.
  FutureOr<A> runOrThrowWith(
    BuildContext context, {
    DeferredIO<Never>? interruptionSignal,
  }) =>
      context.registry(listen: false).get(runtimeAtom).runOrThrow(
            this,
            interruptionSignal: interruptionSignal,
          );

  /// Runs this [ZIO] synchronously and returns the result as an [Exit].
  Exit<E, A> runSyncWith(
    BuildContext context, {
    DeferredIO<Never>? interruptionSignal,
  }) =>
      context.registry(listen: false).get(runtimeAtom).runSync(
            this,
            interruptionSignal: interruptionSignal,
          );

  /// Runs this [ZIO] synchronously and throws if it fails.
  A runSyncOrThrowWith(BuildContext context) =>
      context.registry(listen: false).get(runtimeAtom).runSyncOrThrow(this);
}
