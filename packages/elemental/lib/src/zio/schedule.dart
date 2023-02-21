part of '../zio.dart';

class Schedule<R, E, I, O> {
  Schedule._(this._transform);
  final ZIO<R, Option<E>, O> Function(I input, int count) _transform;

  static Schedule<NoEnv, Never, dynamic, int> fixed(Duration duration) =>
      Schedule._(
        (input, count) => IO.succeed(count).delay(duration),
      );

  static Schedule<NoEnv, Never, dynamic, int> forever() =>
      Schedule._((input, count) => ZIO.succeed(count));

  static Schedule<NoEnv, Never, dynamic, int> recursN<R, E, I>(int n) =>
      Schedule._(
        (input, count) => n >= count ? ZIO.succeed(count) : ZIO.fail(None()),
      );

  static Schedule<NoEnv, Never, I, int> recursWhile<I>(bool Function(I _) f) =>
      Schedule._(
        (input, count) => f(input) ? ZIO.succeed(count) : ZIO.fail(None()),
      );

  static Schedule<R, E, I, int> recursWhileZIO<R, E, I>(
    ZIO<R, E, bool> Function(I _) f,
  ) =>
      Schedule._(
        (input, count) => f(input).mapError(Option.of).flatMap(
              (repeat) => repeat ? ZIO.succeed(count) : ZIO.fail(None()),
            ),
      );

  Schedule<R, E, I, O> delay(Duration duration) => Schedule._(
        (input, count) => _transform(input, count).delay(duration),
      );

  Schedule<R, E, I, B> map<B>(B Function(O _) f) => Schedule._(
        (input, count) => _transform(input, count).map(f),
      );

  Schedule<R, E, I, B> mapZIO<B>(ZIO<R, Option<E>, B> Function(O _) f) =>
      Schedule._(
        (input, count) => _transform(input, count).flatMap(f),
      );

  Schedule<R, E, I, O> tap<X>(ZIO<R, Option<E>, X> Function(O _) f) =>
      Schedule._(
        (input, count) => _transform(input, count).tap(f),
      );

  Schedule<R, E, I, O> times(int n) => Schedule._(
        (input, count) =>
            n >= count ? _transform(input, count) : ZIO.fail(None()),
      );

  IO<ScheduleDriver<R, E, I, O>> get driver => IO(() => ScheduleDriver(this));
}

class ScheduleDriver<R, E, I, O> {
  ScheduleDriver(this._schedule);

  final Schedule<R, E, I, O> _schedule;
  final _count = Ref.unsafeMake(0);

  ZIO<R, Option<E>, O> next(I input) => _count
      .updateAndGet((_) => _ + 1)
      .lift<R, Option<E>>()
      .flatMap((count) => _schedule._transform(input, count));
}

extension SchedultLiftIOExt<O> on Schedule<NoEnv, Never, dynamic, O> {
  Schedule<R, E, I, O> lift<R, E, I>() => Schedule._(
        (input, count) => _transform(input, count).lift(),
      );

  Schedule<NoEnv, E, I, O> liftError<E, I>() => Schedule._(
        (input, count) => _transform(input, count).liftError(),
      );
}

extension SchedultLiftEIOExt<E extends Object?, O>
    on Schedule<NoEnv, E, dynamic, O> {
  Schedule<R, E, I, O> lift<R, I>() => Schedule._(
        (input, count) => _transform(input, count).lift(),
      );

  Schedule<NoEnv, E2, I, O> liftError<E2, I>() => Schedule._(
        (input, count) => _transform(input, count).liftError(),
      );
}

extension SchedultLiftRIOExt<R, O> on Schedule<R, Never, dynamic, O> {
  Schedule<R, E, I, O> lift<E, I>() => Schedule._(
        (input, count) => _transform(input, count),
      );

  Schedule<R, E, I, O> liftError<E, I>() => lift();
}
