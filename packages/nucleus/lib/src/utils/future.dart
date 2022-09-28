import 'package:nucleus/nucleus.dart';

/// Represents an [AtomWithParent] for an async operation.
typedef FutureAtom<A> = AtomWithParent<FutureValue<A>, Atom<Future<A>>>;

/// Create an [AtomWithParent] that returns a [FutureValue] representing the
/// current state of the [Future]'s execution.
///
/// The `parent` property is set to the [Future] itself, so you can `await` it
/// if required.
FutureAtom<A> futureAtom<A>(
  AtomReader<Future<A>> create,
) =>
    AtomWithParent(ReadOnlyAtom(create), (get, future) {
      bool disposed = false;
      get.onDispose(() => disposed = true);

      get(future).then((value) {
        if (disposed) return;
        get.setSelf(FutureValue.data(value));
      }, onError: (err, stack) {
        if (disposed) return;
        get.setSelf(FutureValue.error(err, stack));
      });

      return FutureValue.loading(get.self()?.dataOrNull);
    });

/// Represents the loading, error and data state of an async operation.
abstract class FutureValue<A> {
  const FutureValue();

  const factory FutureValue.data(A data) = FutureData;
  const factory FutureValue.loading([A? previousData]) = FutureLoading;
  const factory FutureValue.error(dynamic error, StackTrace stackTrace) =
      FutureError;

  /// Attempt to read the data from this [FutureValue], otherwise return `null`
  /// if it is in a loading or error state.
  A? get dataOrNull;

  /// Is the data still loading?
  bool get isLoading => this is FutureLoading;

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

  FutureValue<Tuple2<A, B>> combineWith<B>(FutureValue<B> other) {
    final self = this;
    if (self is FutureError<A>) {
      return FutureValue.error(self.error, self.stackTrace);
    } else if (other is FutureError<B>) {
      return FutureValue.error(other.error, other.stackTrace);
    }

    final loading = isLoading || other.isLoading;
    final data = (dataOrNull != null && other.dataOrNull != null)
        // ignore: null_check_on_nullable_type_parameter
        ? Tuple2(dataOrNull!, other.dataOrNull!)
        : null;

    return loading || data == null
        ? FutureValue.loading(data)
        : FutureValue.data(data);
  }

  FutureValue<Tuple3<A, B, C>> combineWith2<B, C>(
    FutureValue<B> one,
    FutureValue<C> two,
  ) =>
      combineWith(one).combineWith(two).when(
            data: (t) => FutureValue.data(Tuple3(
              t.first.first,
              t.first.second,
              t.second,
            )),
            error: (error, stackTrace) => FutureValue.error(error, stackTrace),
            loading: (t) => FutureValue.loading(
              t != null
                  ? Tuple3(
                      t.first.first,
                      t.first.second,
                      t.second,
                    )
                  : null,
            ),
          );
}

/// Represents the case where an async operation succeeds, and has returned a
/// some [data].
class FutureData<A> extends FutureValue<A> {
  const FutureData(this.data) : dataOrNull = data;

  final A data;

  @override
  final A? dataOrNull;

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

/// Represents the case where an async operation fails, and has returned an
/// [error].
class FutureError<A> extends FutureValue<A> {
  const FutureError(this.error, this.stackTrace);

  final dynamic error;
  final StackTrace stackTrace;

  @override
  final A? dataOrNull = null;

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

/// Represents the case where an async operation is waiting for a result.
///
/// It may contain the [previousData] from a previous operation.
class FutureLoading<A> extends FutureValue<A> {
  const FutureLoading([this.previousData]) : dataOrNull = previousData;

  final A? previousData;

  @override
  final A? dataOrNull;

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
