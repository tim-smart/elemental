import 'package:flutter/widgets.dart';
import 'package:flutter_elemental/flutter_elemental.dart';

Future<AtomScope> atomScopeWithLayers(
  Iterable<Layer> layers, {
  Logger? logger,
  LogLevel? logLevel,
  List<AtomInitialValue> initialValues = const [],
  Key? key,
  required Widget child,
}) {
  final scope = AtomScope(initialValues: initialValues, child: child);

  return Runtime.withLayers(
    layers,
    registry: scope.registry,
    logger: logger,
    logLevel: logLevel,
  ).as(scope).runFuture();
}
