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

  ZIO<R, E, A> get<R, E>() => ZIO(() => _value);
  IO<A> get getIO => get();

  A unsafeGet() => _value;

  ZIO<R, E, Unit> set<R, E>(A a) => ZIO(() {
        _value = a;
        _controller?.add(_value);
        return unit;
      });
  IO<Unit> setIO(A a) => set(a);

  ZIO<R, E, A> getAndSet<R, E>(A a) => ZIO(() {
        final old = _value;
        _value = a;
        _controller?.add(_value);
        return old;
      });
  IO<A> getAndSetIO(A a) => getAndSet(a);

  ZIO<R, E, Unit> update<R, E>(A Function(A _) f) => ZIO(() {
        _value = f(_value);
        _controller?.add(_value);
        return unit;
      });
  IO<Unit> updateIO(A Function(A _) f) => update(f);

  ZIO<R, E, A> getAndUpdate<R, E>(A Function(A _) f) => ZIO(() {
        final old = _value;
        _value = f(_value);
        _controller?.add(_value);
        return old;
      });
  IO<A> getAndUpdateIO(A Function(A _) f) => getAndUpdate(f);

  ZIO<R, E, A> updateAndGet<R, E>(A Function(A _) f) => ZIO(() {
        _value = f(_value);
        _controller?.add(_value);
        return _value;
      });
  IO<A> updateAndGetIO(A Function(A _) f) => updateAndGet(f);
}
