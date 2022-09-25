part of 'internal.dart';

typedef SchedulerRunner = void Function(void Function());

void microtaskSchedulerRunner(void Function() task) {
  Future.microtask(task);
}

class Scheduler {
  Scheduler({
    SchedulerRunner? postFrameRunner,
  }) : _postFrameRunner = postFrameRunner ?? microtaskSchedulerRunner;

  var _postFrameCallbacks = List<void Function()?>.filled(
    16,
    null,
    growable: true,
  );
  var _postFrameCount = 0;
  final SchedulerRunner _postFrameRunner;
  bool _postFrameScheduled = false;

  void runPostFrame(void Function() f) {
    if (_postFrameCount == _postFrameCallbacks.length) {
      _postFrameCallbacks.add(f);
      _postFrameCount++;
    } else {
      _postFrameCallbacks[_postFrameCount++] = f;
    }

    if (!_postFrameScheduled) {
      _postFrameScheduled = true;
      _postFrameRunner(_postFrame);
    }
  }

  void _postFrame() {
    _postFrameScheduled = false;

    final count = _postFrameCount;
    final callbacks = _postFrameCallbacks;

    _postFrameCallbacks = List.filled(callbacks.length, null);
    _postFrameCount = 0;

    for (var i = 0; i < count; i++) {
      callbacks[i]!();
    }
  }
}
