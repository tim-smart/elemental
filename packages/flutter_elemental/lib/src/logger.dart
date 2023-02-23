import 'dart:io';

import 'package:flutter_elemental/flutter_elemental.dart';

void _printStderr(String message) {
  stderr.writeln(message);
}

class FlutterLogger extends Logger {
  const FlutterLogger() : super(_printStderr);
}

final flutterLoggerLayer = loggerLayer.replace(IO(FlutterLogger.new));
