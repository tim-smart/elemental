part of 'internal.dart';

class Scheduler {
  final _postFrameCallbacks = List<void Function()?>.filled(
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
    _postFrameCount = 0;

    for (var i = 0; i < count; i++) {
      _postFrameCallbacks[i]!();
      _postFrameCallbacks[i] = null;
    }
  }
}
