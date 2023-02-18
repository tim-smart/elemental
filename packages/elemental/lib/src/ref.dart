import 'dart:async';

import 'package:elemental/elemental.dart';

class Ref<A> {
  Ref(this._value);

  A _value;

  StreamController<A>? _controller;
  Stream<A> get stream {
    _controller ??= StreamController(sync: true);
    return _controller!.stream;
  }

  IO<A> get get => ZIO(() => _value);

  IO<Unit> set(A a) => ZIO(() {
        _value = a;
        _controller?.add(_value);
        return unit;
      });

  IO<A> getAndSet(A a) => ZIO(() {
        final old = _value;
        _value = a;
        _controller?.add(_value);
        return old;
      });

  IO<Unit> update<R, E>(A Function(A) f) => ZIO(() {
        _value = f(_value);
        _controller?.add(_value);
        return unit;
      });

  IO<A> getAndUpdate(A Function(A) f) => ZIO(() {
        final old = _value;
        _value = f(_value);
        _controller?.add(_value);
        return old;
      });

  IO<A> updateAndGet(A Function(A) f) => ZIO(() {
        _value = f(_value);
        _controller?.add(_value);
        return _value;
      });

  IO<Unit> get dispose => IO.unsafeFuture(() => _controller?.close()).asUnit;
}
