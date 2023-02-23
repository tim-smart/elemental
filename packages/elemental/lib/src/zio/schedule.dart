part of '../zio.dart';

Option<Duration> _remainingWindow(
  Option<DateTime> lastTick,
  Duration duration,
) {
  if (lastTick.isNone()) return Option.of(duration);

  final endOfWindow = DateTime.now().subtract(duration);
  return lastTick
      .filter((lastTick) => lastTick.isAfter(endOfWindow))
      .map((dt) => dt.difference(endOfWindow));
}

class Schedule<R, E, I, O> {
  Schedule._(this._transform);
  final ZIO<R, Option<E>, O> Function(
      I input, int count, Option<DateTime> lastTick) _transform;

  static Schedule<NoEnv, Never, I, int> fixed<I>(Duration duration) =>
      Schedule._(
        (input, count, lastTick) => IO(
          () => _remainingWindow(lastTick, duration),
        ).flatMap(
          (_) => _.match(
            () => IO.succeed(count),
            (duration) => ZIO.sleepIO(duration).as(count),
          ),
        ),
      );

  static Schedule<NoEnv, Never, I, int> forever<I>() =>
      Schedule._((input, count, lastTick) => ZIO.succeed(count));

  static Schedule<NoEnv, Never, I, int> recursN<R, E, I>(int n) => Schedule._(
        (input, count, lastTick) =>
            n >= count ? ZIO.succeed(count) : ZIO.fail(const None()),
      );

  static Schedule<NoEnv, Never, I, int> recursWhile<I>(bool Function(I _) f) =>
      Schedule._(
        (input, count, lastTick) =>
            f(input) ? ZIO.succeed(count) : ZIO.fail(const None()),
      );

  static Schedule<R, E, I, int> recursWhileZIO<R, E, I>(
    ZIO<R, E, bool> Function(I _) f,
  ) =>
      Schedule._(
        (input, count, lastTick) => f(input).mapError(Option.of).flatMap(
              (repeat) => repeat ? ZIO.succeed(count) : ZIO.fail(const None()),
            ),
      );

  Schedule<R, E, I, O> delay(Duration duration) => Schedule._(
        (input, count, lastTick) =>
            _transform(input, count, lastTick).delay(duration),
      );

  Schedule<R, E, I, B> map<B>(B Function(O _) f) => Schedule._(
        (input, count, lastTick) => _transform(input, count, lastTick).map(f),
      );

  Schedule<R, E, I, B> mapZIO<B>(ZIO<R, Option<E>, B> Function(O _) f) =>
      Schedule._(
        (input, count, lastTick) =>
            _transform(input, count, lastTick).flatMap(f),
      );

  Schedule<R, E, I, I> get passthrough => Schedule._(
        (input, count, lastTick) =>
            _transform(input, count, lastTick).as(input),
      );

  Schedule<R, E, I, O> tap<X>(ZIO<R, Option<E>, X> Function(O _) f) =>
      Schedule._(
        (input, count, lastTick) => _transform(input, count, lastTick).tap(f),
      );

  Schedule<R, E, I, O> times(int n) => Schedule._(
        (input, count, lastTick) => n >= count
            ? _transform(input, count, lastTick)
            : ZIO.fail(const None()),
      );

  ZIO<R2, E2, ScheduleDriver<R, E, I, O>> driver<R2, E2>() =>
      ZIO(() => ScheduleDriver(this));
}

class ScheduleDriver<R, E, I, O> {
  ScheduleDriver(this._schedule);

  final Schedule<R, E, I, O> _schedule;
  final _count = Ref.unsafeMake(0);
  final _lastTick = Ref.unsafeMake(Option<DateTime>.none());

  ZIO<R, Option<E>, O> next(I input) => _count
      .updateAndGet<R, Option<E>>((_) => _ + 1)
      .flatMap(
        (count) => _schedule._transform(input, count, _lastTick.unsafeGet()),
      )
      .tap((_) => _lastTick.set(Option.of(DateTime.now())));
}

extension SchedultLiftIOExt<O> on Schedule<NoEnv, Never, dynamic, O> {
  Schedule<R, E, I, O> lift<R, E, I>() => Schedule._(
        (input, count, lastTick) => _transform(input, count, lastTick).lift(),
      );

  Schedule<NoEnv, E, I, O> liftError<E, I>() => Schedule._(
        (input, count, lastTick) =>
            _transform(input, count, lastTick).liftError(),
      );
}

extension SchedultLiftEIOExt<E extends Object?, O>
    on Schedule<NoEnv, E, dynamic, O> {
  Schedule<R, E, I, O> lift<R, I>() => Schedule._(
        (input, count, lastTick) => _transform(input, count, lastTick).lift(),
      );

  Schedule<NoEnv, E2, I, O> liftError<E2, I>() => Schedule._(
        (input, count, lastTick) =>
            _transform(input, count, lastTick).liftError(),
      );
}

extension SchedultLiftRIOExt<R, O> on Schedule<R, Never, dynamic, O> {
  Schedule<R, E, I, O> lift<E, I>() => Schedule._(
        (input, count, lastTick) => _transform(input, count, lastTick),
      );

  Schedule<R, E, I, O> liftError<E, I>() => lift();
}
