import 'package:flutter_elemental/flutter_elemental.dart';

Future<AtomInitialValue<Runtime>> runtimeInitialValue(
  Iterable<Layer> layers, {
  LogLevel? logLevel,
  Logger? logger,
}) =>
    Runtime.withLayers([
      if (logger == null) flutterLoggerLayer,
      ...layers,
    ], logLevel: logLevel)
        .map(runtimeAtom.withInitialValue)
        .runFutureOrThrow();
