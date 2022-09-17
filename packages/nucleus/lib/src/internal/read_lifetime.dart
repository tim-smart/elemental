import 'internal.dart';

class ReadLifetime {
  ReadLifetime(this._builder);

  final disposers = <void Function()>[];
  var disposed = false;

  final LifetimeDepsFn _builder;

  dynamic create() => _builder(disposers.add, _assertNotDisposed);

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
