part of '../zio.dart';

extension EIORunnerExt<E, A> on EIO<E, A> {
  IO<ZIORunner<E, A>> get runner => ZIORunner.make(this);
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
        .flatMap2((_) => ZIO.runtime())
        .map((a) => ZIORunner._(a.second, zio, scope, a.first))
        .provide(scope);
  }

  final Runtime _runtime;
  final EIO<E, A> _zio;
  final Scope _scope;
  final Ref<ZIORunnerState<E, A>> _ref;
  final _interrupt = DeferredIO<Unit>();
  DeferredIO<Exit<E, A>>? _deferred;

  ZIORunnerState<E, A> get state => _ref.unsafeGet();

  Stream<ZIORunnerState<E, A>> get stream => _ref.stream;

  late final _run = _ref
      .update<NoEnv, E>((s) => s.copyWith(loading: true))
      .zipRight(_zio)
      .tapExit(_deferred!.complete)
      .tapEither((_) => _ref.update((s) => s.copyWith(
            loading: false,
            value: _.match(
              (e) => s.value,
              Option.of,
            ),
            error: _.swap().toOption(),
          )));

  FutureOr<Exit<E, A>> run() {
    if (_deferred == null || _deferred!.unsafeCompleted) {
      _deferred = Deferred();
      return _runtime.run(_run, interruptionSignal: _interrupt);
    }

    return _runtime.runOrThrow(
      _deferred!.awaitIO,
      interruptionSignal: _interrupt,
    );
  }

  Future<A> runOrThrow() =>
      Future.sync(run).then((value) => value.getOrElse((l) => throw l));

  void dispose() =>
      _interrupt.completeIO(unit).zipRight(_scope.closeScopeIO).run();
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
