class Scheduler {
  // Post frame
  var _postFrameCallbacks = <void Function()>[];
  Future<void>? _postFrameFuture;

  void runPostFrame(void Function() f) {
    _postFrameCallbacks.add(f);
    _postFrameFuture ??= Future.microtask(_postFrame);
  }

  void _postFrame() {
    _postFrameFuture = null;

    final callbacks = _postFrameCallbacks;
    _postFrameCallbacks = [];

    for (final f in callbacks) {
      f();
    }
  }
}
