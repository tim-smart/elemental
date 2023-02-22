part of '../zio.dart';

class Deferred<A> {
  Deferred();

  Deferred.completed(A value) : _value = Option.of(value);

  Option<A> _value = Option.none();
  final _completer = Completer<A>.sync();

  IO<bool> get completed => IO(_value.isSome);
  bool get unsafeCompleted => _value.isSome();

  ZIO<R, E, A> await<R, E>() => ZIO.from((ctx) {
        return _value.match(
          () => _completer.future.then(Exit.right),
          (value) => Exit.right(value),
        );
      });
  late final IO<A> awaitIO = await();

  ZIO<R, E, Unit> complete<R, E>(A value) => ZIO(() => _value.match(
        () {
          _value = Option.of(value);
          _completer.complete(value);
          return unit;
        },
        (_) => unit,
      ));
  IO<Unit> completeIO(A value) => complete(value);
}
