part of 'internal.dart';

typedef SchedulerRunner = void Function(void Function());

void microtaskSchedulerRunner(void Function() task) {
  Future.microtask(task);
}

class Scheduler {
  Scheduler({
    SchedulerRunner? postFrameRunner,
  }) : _postFrameRunner = postFrameRunner ?? microtaskSchedulerRunner;

  Listener? _postFrameCallbacks;
  final SchedulerRunner _postFrameRunner;
  bool _postFrameScheduled = false;

  void runPostFrame(void Function() f) {
    _postFrameCallbacks = Listener(
      fn: f,
      next: _postFrameCallbacks,
    );

    if (!_postFrameScheduled) {
      _postFrameScheduled = true;
      _postFrameRunner(_postFrame);
    }
  }

  void _postFrame() {
    _postFrameScheduled = false;

    var listener = _postFrameCallbacks;
    _postFrameCallbacks = null;

    while (listener != null) {
      listener.fn();
      listener = listener.next;
    }
  }
}
