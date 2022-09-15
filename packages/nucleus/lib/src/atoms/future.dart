import 'package:nucleus/nucleus.dart';

class FutureAtom<A> extends Atom<FutureValue<A>> {
  FutureAtom(AtomReader<Future<A>> create) : future = ReadOnlyAtom(create) {
    keepAlive();
  }

  final Atom<Future<A>> future;

  @override
  void keepAlive() {
    future.keepAlive();
    super.keepAlive();
  }

  @override
  void autoDispose() {
    future.autoDispose();
    super.autoDispose();
  }

  @override
  FutureValue<A> read(AtomContext<FutureValue<A>> _) {
    bool disposed = false;
    _.onDispose(() => disposed = true);

    _(future).then((value) {
      if (disposed) return;
      _.setSelf(FutureValue.data(value));
    }, onError: (err, stack) {
      if (disposed) return;
      _.setSelf(FutureValue.error(err, stack));
    });

    final prev = _.previousValue;
    return prev is FutureData<A>
        ? FutureValue.loading(prev.data)
        : FutureValue.loading();
  }
}

FutureAtom<T> futureAtom<T>(AtomReader<Future<T>> create) => FutureAtom(create);

// ==== FutureValue

abstract class FutureValue<A> {
  const FutureValue();

  const factory FutureValue.data(A data) = FutureData;
  const factory FutureValue.loading([A? previousData]) = FutureLoading;
  const factory FutureValue.error(dynamic error, StackTrace stackTrace) =
      FutureError;

  FutureValue<B> map<B>(B Function(A a) f);

  B when<B>({
    required B Function(A a) data,
    required B Function(dynamic error, StackTrace stackTrace) error,
    required B Function(A? previousData) loading,
  });

  B whenOrElse<B>({
    B Function(A a)? data,
    B Function(dynamic error, StackTrace stackTrace)? error,
    B Function(A? previousData)? loading,
    required B Function() orElse,
  });
}

class FutureData<A> extends FutureValue<A> {
  const FutureData(this.data);

  final A data;

  @override
  FutureValue<B> map<B>(B Function(A a) f) => FutureData(f(data));

  @override
  B when<B>({
    required B Function(A a) data,
    required B Function(dynamic error, StackTrace stackTrace) error,
    required B Function(A? previousData) loading,
  }) =>
      data(this.data);

  @override
  B whenOrElse<B>({
    B Function(A a)? data,
    B Function(dynamic error, StackTrace stackTrace)? error,
    B Function(A? previousData)? loading,
    required B Function() orElse,
  }) =>
      data?.call(this.data) ?? orElse();

  @override
  operator ==(Object? other) => other is FutureData<A> && other.data == data;

  @override
  int get hashCode => Object.hash(runtimeType, data);

  @override
  String toString() => "FutureValue<$A>.data(data: $data)";
}

class FutureError<A> extends FutureValue<A> {
  const FutureError(this.error, this.stackTrace);

  final dynamic error;
  final StackTrace stackTrace;

  @override
  FutureValue<B> map<B>(B Function(A a) f) => FutureError(error, stackTrace);

  @override
  B when<B>({
    required B Function(A a) data,
    required B Function(dynamic error, StackTrace stackTrace) error,
    required B Function(A? previousData) loading,
  }) =>
      error(this.error, stackTrace);

  @override
  B whenOrElse<B>({
    B Function(A a)? data,
    B Function(dynamic error, StackTrace stackTrace)? error,
    B Function(A? previousData)? loading,
    required B Function() orElse,
  }) =>
      error?.call(this.error, stackTrace) ?? orElse();

  @override
  operator ==(Object? other) =>
      other is FutureError<A> &&
      other.error == error &&
      other.stackTrace == stackTrace;

  @override
  int get hashCode => Object.hash(runtimeType, error, stackTrace);

  @override
  String toString() => "FutureValue<$A>.error(error: $error)";
}

class FutureLoading<A> extends FutureValue<A> {
  const FutureLoading([this.previousData]);

  final A? previousData;

  @override
  FutureValue<B> map<B>(B Function(A a) f) =>
      // ignore: null_check_on_nullable_type_parameter
      FutureLoading(previousData != null ? f(previousData!) : null);

  @override
  B when<B>({
    required B Function(A a) data,
    required B Function(dynamic error, StackTrace stackTrace) error,
    required B Function(A? previousData) loading,
  }) =>
      loading(previousData);

  @override
  B whenOrElse<B>({
    B Function(A a)? data,
    B Function(dynamic error, StackTrace stackTrace)? error,
    B Function(A? previousData)? loading,
    required B Function() orElse,
  }) =>
      loading?.call(previousData) ?? orElse();

  @override
  operator ==(Object? other) =>
      other is FutureLoading<A> && other.previousData == previousData;

  @override
  int get hashCode => Object.hash(runtimeType, previousData);

  @override
  String toString() => "FutureValue<$A>.loading(data: $previousData)";
}
