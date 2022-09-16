import 'internal.dart';

class ReadLifetime<A> {
  ReadLifetime(LifetimeDepsFn<A> builder) {
    create = builder(disposers.add, _assertNotDisposed);
  }

  final disposers = <void Function()>[];
  var calledSetSelf = false;
  var disposed = false;

  late final ValueBuilder<A> create;

  void _assertNotDisposed(String method) {
    if (disposed) {
      throw UnsupportedError("can not call $method after onDispose");
    }
  }

  void dispose() {
    if (disposed) return;
    disposed = true;

    if (disposers.isEmpty) return;

    for (final f in disposers) {
      f();
    }
    disposers.clear();
  }
}
