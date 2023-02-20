part of '../zio.dart';

class Ref<A> {
  Ref.unsafeMake(this._value);

  static RIO<R, Ref<A>> make<R extends ScopeMixin, A>(A a) =>
      RIO<R, Ref<A>>(() => Ref.unsafeMake(a)).acquireRelease(
        (ref) => IO(() => ref._controller?.close()).asUnit,
      );

  static RIO<Scope, Ref<A>> makeScope<A>(A a) =>
      IO(() => Ref.unsafeMake(a)).acquireRelease(
        (ref) => IO(() => ref._controller?.close()).asUnit,
      );

  A _value;

  StreamController<A>? _controller;
  Stream<A> get stream {
    _controller ??= StreamController(sync: true);
    return _controller!.stream;
  }

  IO<A> get get => IO(() => _value);

  A unsafeGet() => _value;

  IO<Unit> set(A a) => IO(() {
        _value = a;
        _controller?.add(_value);
        return unit;
      });

  IO<A> getAndSet(A a) => IO(() {
        final old = _value;
        _value = a;
        _controller?.add(_value);
        return old;
      });

  IO<Unit> update<R, E>(A Function(A) f) => IO(() {
        _value = f(_value);
        _controller?.add(_value);
        return unit;
      });

  IO<A> getAndUpdate(A Function(A) f) => IO(() {
        final old = _value;
        _value = f(_value);
        _controller?.add(_value);
        return old;
      });

  IO<A> updateAndGet(A Function(A) f) => IO(() {
        _value = f(_value);
        _controller?.add(_value);
        return _value;
      });
}
