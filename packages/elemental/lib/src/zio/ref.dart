part of '../zio.dart';

/// A [Ref] holds a value of type [A] and allows to modify it atomically.
class Ref<A> {
  /// Creates a new [Ref] with the given initial value.
  ///
  /// It is unsafe because it does not acquire a [Scope] and therefore
  /// the internal [StreamController] will not be disposed.
  Ref.unsafeMake(this._value);

  /// Disposes the internal [StreamController].
  void unsafeDispose() => _controller?.close();

  /// Creates a new [Ref] with the given initial value.
  /// The [Ref] will be disposed when the scope is disposed.
  ///
  /// Allows for a custom environment [R] to be used, as long as it includes [ScopeMixin].
  static RIO<R, Ref<A>> makeWith<R extends ScopeMixin, A>(A a) =>
      RIO<R, Ref<A>>(() => Ref.unsafeMake(a)).acquireRelease(
        (ref) => IO(ref.unsafeDispose).asUnit,
      );

  /// Creates a new [Ref] with the given initial value.
  ///
  /// The [Ref] will be disposed when the [Scope] is disposed.
  static RIO<Scope, Ref<A>> make<A>(A a) =>
      IO(() => Ref.unsafeMake(a)).acquireRelease(
        (ref) => IO(() => ref._controller?.close()).asUnit,
      );

  A _value;

  StreamController<A>? _controller;

  /// Access a [Stream] of the value for this [Ref].
  Stream<A> get stream {
    _controller ??= StreamController.broadcast(sync: true);
    return _controller!.stream;
  }

  /// Called every time the value changes.
  @mustCallSuper
  void unsafeValueDidChange(A value) {
    _value = value;
    _controller?.add(_value);
  }

  /// Returns the current value.
  ZIO<R, E, A> get<R, E>() => ZIO(() => _value);

  /// [IO] version of [get].
  IO<A> get getIO => get();

  /// Unsafe version of [get].
  A unsafeGet() => _value;

  /// Sets the value to [a].
  ZIO<R, E, Unit> set<R, E>(A a) => ZIO(() {
        unsafeValueDidChange(a);
        return unit;
      });

  /// [IO] version of [set].
  IO<Unit> setIO(A a) => set(a);

  /// Gets the current value and then sets it to [a].
  ///
  /// Returns the old value.
  ZIO<R, E, A> getAndSet<R, E>(A a) => ZIO(() {
        final old = _value;
        unsafeValueDidChange(a);
        return old;
      });

  /// [IO] version of [getAndSet].
  IO<A> getAndSetIO(A a) => getAndSet(a);

  /// Updates the value using the given function.
  ZIO<R, E, Unit> update<R, E>(A Function(A _) f) => ZIO(() {
        unsafeValueDidChange(f(_value));
        return unit;
      });

  /// [IO] version of [update].
  IO<Unit> updateIO(A Function(A _) f) => update(f);

  /// Gets the current value and then updates it using the given function.
  ///
  /// Returns the old value.
  ZIO<R, E, A> getAndUpdate<R, E>(A Function(A _) f) => ZIO(() {
        final old = _value;
        unsafeValueDidChange(f(_value));
        return old;
      });

  /// [IO] version of [getAndUpdate].
  IO<A> getAndUpdateIO(A Function(A _) f) => getAndUpdate(f);

  /// Updates the value using the given function and returns the new value.
  ZIO<R, E, A> updateAndGet<R, E>(A Function(A _) f) => ZIO(() {
        unsafeValueDidChange(f(_value));
        return _value;
      });

  /// [IO] version of [updateAndGet].
  IO<A> updateAndGetIO(A Function(A _) f) => updateAndGet(f);
}
