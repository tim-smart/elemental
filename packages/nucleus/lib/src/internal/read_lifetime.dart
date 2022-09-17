import 'internal.dart';

class ReadLifetime {
  ReadLifetime(LifetimeDepsFn builder) {
    create = builder(disposers.add, _assertNotDisposed);
  }

  final disposers = <void Function()>[];
  var disposed = false;

  late final ValueBuilder create;

  void _assertNotDisposed(String method) {
    if (disposed) {
      throw UnsupportedError("can not call $method after onDispose");
    }
  }

  void dispose() {
    assert(!disposed);
    disposed = true;

    if (disposers.isEmpty) return;

    for (final f in disposers) {
      f();
    }
    disposers.clear();
  }
}
