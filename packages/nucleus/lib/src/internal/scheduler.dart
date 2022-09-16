import 'dart:collection';

class Scheduler {
  // Post frame
  final _postFrameCallbacks = <void Function()>[];
  Future<void>? _postFrameFuture;

  void runPostFrame(void Function() f) {
    _postFrameCallbacks.add(f);
    _postFrameFuture ??= Future.microtask(_postFrame);
  }

  void _postFrame() {
    _postFrameFuture = null;

    for (final f in _postFrameCallbacks) {
      f();
    }
    _postFrameCallbacks.clear();
  }

  // End of frame
  final _endOfFrameCallbacks = HashMap<Object?, void Function()>();
  void runEndOfFrame(Object? key, void Function() f) =>
      _endOfFrameCallbacks[key] = f;

  void flushEndOfFrame() {
    for (final f in _endOfFrameCallbacks.values) {
      f();
    }
    _endOfFrameCallbacks.clear();
  }
}
