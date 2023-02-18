import 'dart:async';

import 'package:elemental/elemental.dart';

class Deferred<A> {
  Deferred();

  Option<A> _value = Option.none();
  final _completer = Completer<A>.sync();

  IO<A> get await => _value.match(
        () => ZIO.unsafeFuture(() => _completer.future),
        (value) => ZIO.succeed(value),
      );

  IO<Unit> complete<R, E>(A value) => _value.match(
        () {
          _value = Option.of(value);
          _completer.complete(value);
          return IO.unit();
        },
        (_) => IO.unit(),
      );
}
