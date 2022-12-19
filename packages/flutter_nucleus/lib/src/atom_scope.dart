import 'package:flutter/widgets.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_nucleus/flutter_nucleus.dart';
// ignore: implementation_imports
import 'package:nucleus/src/internal/internal.dart' as internal;

class AtomScope extends InheritedWidget {
  AtomScope({
    super.key,
    required super.child,
    List<AtomInitialValue> initialValues = const [],
  }) : registry = AtomRegistry(
          initialValues: initialValues,
          scheduler: _buildScheduler(),
        );

  static final defaultRegistry = AtomRegistry(scheduler: _buildScheduler());

  static internal.Scheduler _buildScheduler() {
    final binding = SchedulerBinding.instance;

    void postFrame(void Function() task) =>
        binding.addPostFrameCallback((timeStamp) => task());

    return internal.Scheduler(postFrameRunner: postFrame);
  }

  final AtomRegistry registry;

  @override
  bool updateShouldNotify(covariant AtomScope oldWidget) =>
      oldWidget.registry != registry;

  static AtomRegistry registryOf(
    BuildContext context, {
    bool listen = true,
  }) {
    final scope = listen
        ? context.dependOnInheritedWidgetOfExactType<AtomScope>()
        : (context.getElementForInheritedWidgetOfExactType<AtomScope>()?.widget
            as AtomScope?);

    return scope?.registry ?? defaultRegistry;
  }
}
