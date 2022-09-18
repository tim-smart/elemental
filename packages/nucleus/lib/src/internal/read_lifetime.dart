import 'internal.dart';

final _emptyDisposers = List<void Function()>.empty();

class ReadLifetime {
  ReadLifetime(this._builder);

  var disposers = _emptyDisposers;
  var disposed = false;

  final LifetimeDepsFn _builder;

  dynamic create() => _builder(onDispose, _assertNotDisposed);

  void _assertNotDisposed(String method) {
    if (disposed) {
      throw UnsupportedError("can not call $method after onDispose");
    }
  }

  void onDispose(void Function() onDispose) {
    if (disposers == _emptyDisposers) {
      disposers = [onDispose];
    } else {
      disposers.add(onDispose);
    }
  }

  void dispose() {
    assert(!disposed);
    disposed = true;

    if (disposers == _emptyDisposers) {
      return;
    }

    for (final f in disposers) {
      f();
    }
    disposers = _emptyDisposers;
  }
}
