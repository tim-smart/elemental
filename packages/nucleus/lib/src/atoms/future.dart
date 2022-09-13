import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:nucleus/nucleus.dart';

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
  operator ==(Object? other) => other is FutureData<A> && other.data == data;

  @override
  int get hashCode => Object.hash(runtimeType, data);
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
  operator ==(Object? other) =>
      other is FutureError<A> &&
      other.error == error &&
      other.stackTrace == stackTrace;

  @override
  int get hashCode => Object.hash(runtimeType, error, stackTrace);
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
  operator ==(Object? other) =>
      other is FutureLoading<A> && other.previousData == previousData;

  @override
  int get hashCode => Object.hash(runtimeType, previousData);
}

AtomBase<FutureValue<T>> futureAtom<T>(
  AtomReader<Future<T>> create, {
  bool? keepAlive,
}) {
  void createFuture(ManagedAtomContext<FutureValue<T>> ctx) async {
    bool disposed = false;
    ctx.onDispose(() => disposed = true);

    final previous = ctx.previousValue;
    if (previous is FutureData<T>) {
      ctx.set(FutureValue.loading(previous.data));
    }

    try {
      final result = await create(ctx.get);
      if (disposed) return;
      ctx.set(FutureValue.data(result));
    } catch (err, stack) {
      if (disposed) return;
      ctx.set(FutureValue.error(err, stack));
    }
  }

  return managedAtom(FutureLoading(), createFuture, keepAlive: keepAlive);
}

Tuple2<AtomBase<FutureValue<A>>, AtomBase<Future<A>>> futureAtomTuple<A>(
  AtomReader<Future<A>> create, {
  bool? keepAlive,
}) {
  final future = derivedAtom(create, keepAlive: keepAlive);
  final value = futureAtom<A>((get) => get(future), keepAlive: keepAlive);
  return Tuple2(value, future);
}
