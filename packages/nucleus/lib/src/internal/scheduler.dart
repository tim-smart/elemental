part of 'internal.dart';

class Scheduler {
  var _postFrameCallbacks = List<void Function()?>.filled(
    32,
    null,
    growable: true,
  );
  var _postFrameCount = 0;

  Future<void>? _postFrameFuture;

  void runPostFrame(void Function() f) {
    if (_postFrameCount == _postFrameCallbacks.length) {
      _postFrameCallbacks.add(f);
      _postFrameCount++;
    } else {
      _postFrameCallbacks[_postFrameCount++] = f;
    }

    _postFrameFuture ??= Future.microtask(_postFrame);
  }

  void _postFrame() {
    _postFrameFuture = null;

    final count = _postFrameCount;
    final callbacks = _postFrameCallbacks;

    _postFrameCallbacks = List.filled(callbacks.length, null);
    _postFrameCount = 0;

    for (var i = 0; i < count; i++) {
      callbacks[i]!();
    }
  }
}
