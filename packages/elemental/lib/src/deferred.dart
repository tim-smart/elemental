import 'dart:async';

import 'package:elemental/elemental.dart';

class Deferred<A> {
  Deferred();

  Option<A> _value = Option.none();
  final _completer = Completer<A>.sync();

  IO<bool> get completed => IO(_value.isSome);

  IO<A> get await => _value.match(
        () => ZIO.unsafeFuture(() => _completer.future),
        (value) => ZIO.succeed(value),
      );

  IO<Unit> complete<R, E>(A value) => _value.match(
        () => IO(() {
          _value = Option.of(value);
          _completer.complete(value);
          return unit;
        }),
        (_) => IO.unit(),
      );
}
