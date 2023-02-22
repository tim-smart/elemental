import 'dart:async';

import 'package:elemental/elemental.dart';

extension ZIOAtomContextExt on AtomContext {
  FutureOr<Exit<E, A>> runZIO<E, A>(
    EIO<E, A> zio, {
    Deferred<Unit>? interrupt,
  }) =>
      registry.zioRuntime.run(zio, interruptionSignal: interrupt);

  Future<Exit<E, A>> runZIOFuture<E, A>(
    EIO<E, A> zio, {
    Deferred<Unit>? interrupt,
  }) =>
      registry.zioRuntime.runFuture(zio, interruptionSignal: interrupt);

  Future<A> runZIOFutureOrThrow<E, A>(
    EIO<E, A> zio, {
    Deferred<Unit>? interrupt,
  }) =>
      registry.zioRuntime.runFutureOrThrow(zio, interruptionSignal: interrupt);

  FutureOr<A> runZIOOrThrow<E, A>(
    EIO<E, A> zio, {
    Deferred<Unit>? interrupt,
  }) =>
      registry.zioRuntime.runOrThrow(zio, interruptionSignal: interrupt);

  ZIORunner<E, A> makeZIORunner<E, A>(EIO<E, A> zio) =>
      registry.zioRuntime.runSyncOrThrow(ZIORunner.make(zio));
}

class ZIORunner<E, A> {
  ZIORunner._(this._runtime, this._zio, this._scope, this._ref);

  static IO<ZIORunner<E, A>> make<E, A>(EIO<E, A> zio) {
    final scope = Scope.closable();

    return Ref.makeScope(ZIORunnerState<E, A>(
      error: Option.none(),
      value: Option.none(),
      loading: false,
    ))
        .flatMap2((_) => ZIO.registry.lift())
        .map((a) => ZIORunner._(a.second.zioRuntime, zio, scope, a.first))
        .provide(scope);
  }

  final Runtime _runtime;
  final EIO<E, A> _zio;
  final Scope _scope;
  final Ref<ZIORunnerState<E, A>> _ref;
  final _interrupt = Deferred<Unit>();
  Deferred<Exit<E, A>>? _deferred;

  Stream<ZIORunnerState<E, A>> get stream => _ref.stream;

  late final _run = _ref
      .update((s) => s.copyWith(loading: true))
      .liftError<E>()
      .zipRight(_zio)
      .tapExit((_) => _deferred!.complete(_).lift())
      .tapEither(
        (_) => _ref
            .update((s) => s.copyWith(
                  loading: false,
                  value: _.toOption(),
                  error: _.swap().toOption(),
                ))
            .lift(),
      );

  FutureOr<Exit<E, A>> run() {
    if (_deferred == null || _deferred!.unsafeCompleted) {
      _deferred = Deferred();
      return _runtime.run(_run, interruptionSignal: _interrupt);
    }

    return _runtime.runOrThrow(
      _deferred!.await,
      interruptionSignal: _interrupt,
    );
  }

  void dispose() => _scope.closeScope.run();
}

class ZIORunnerState<E, A> {
  const ZIORunnerState({
    required this.error,
    required this.value,
    required this.loading,
  });

  final Option<E> error;
  final Option<A> value;
  final bool loading;

  ZIORunnerState<E, A> copyWith({
    Option<E>? error,
    Option<A>? value,
    bool? loading,
  }) =>
      ZIORunnerState<E, A>(
        error: error ?? this.error,
        value: value ?? this.value,
        loading: loading ?? this.loading,
      );

  @override
  String toString() =>
      'ZIORunnerState<$E, $A>(error: $error, value: $value, loading: $loading)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZIORunnerState<E, A> &&
          runtimeType == other.runtimeType &&
          error == other.error &&
          value == other.value &&
          loading == other.loading;

  @override
  int get hashCode => error.hashCode ^ value.hashCode ^ loading.hashCode;
}
