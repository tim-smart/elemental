part of '../zio.dart';

class Deferred<A> {
  Deferred();

  Deferred.completed(A value) : _value = Option.of(value);

  Option<A> _value = Option.none();
  final _completer = Completer<A>.sync();

  IO<bool> get completed => IO(_value.isSome);
  bool get unsafeCompleted => _value.isSome();

  IO<A> get await => _value.match(
        () => IO.unsafeFuture(() => _completer.future),
        (value) => IO.succeed(value),
      );

  IO<Unit> complete<R, E>(A value) => _value.match(
        () => IO(() {
          _value = Option.of(value);
          _completer.complete(value);
          return unit;
        }),
        (_) => IO.unitIO,
      );
}
