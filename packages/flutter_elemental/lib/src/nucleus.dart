import 'package:elemental/elemental.dart';

Future<AtomInitialValue<Runtime>> runtimeInitialValue(
  Iterable<Layer> layers, {
  LogLevel? logLevel,
  Logger? logger,
}) =>
    Runtime.withLayers(
      [...layers],
      logLevel: logLevel,
      logger: logger,
    ).map(runtimeAtom.withInitialValue).runFutureOrThrow();
