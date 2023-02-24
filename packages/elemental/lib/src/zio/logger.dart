part of '../zio.dart';

const loggerAnnotationsSymbol = Symbol("elemental/Logger");

enum LogLevel {
  debug(0, "DEBUG"),
  info(1, "INFO"),
  warn(2, "WARN"),
  error(3, "ERROR");

  const LogLevel(this.level, this.label);

  final int level;
  final String label;

  operator <(LogLevel other) => level < other.level;
  operator <=(LogLevel other) => level <= other.level;
  operator >(LogLevel other) => level > other.level;
  operator >=(LogLevel other) => level >= other.level;
}

final logLevelLayer = Layer(IO.succeed(LogLevel.debug));

// ignore: avoid_print
void _printStdout(String message) => print(message);

class Logger {
  const Logger([this._print = _printStdout]);

  final void Function(String message) _print;

  static String annotationsToString(Map<String, dynamic> annotations) =>
      annotations.entries.map((e) => '${e.key}="${e.value}"').join(' ');

  ZIO<R, E, Unit> log<R, E>(
    LogLevel level,
    DateTime time,
    String message, {
    Map<String, dynamic> annotations = const {},
  }) =>
      ZIO<R, E, LogLevel>.layer(logLevelLayer).flatMap(
        (currentLevel) => level < currentLevel
            ? ZIO.unit()
            : ZIO(() {
                _print(
                  'level=${level.label} time="${time.toIso8601String()}" message="$message"${annotations.isEmpty ? "" : " ${annotationsToString(annotations)}"}',
                );
                return unit;
              }),
      );
}

final loggerLayer = Layer(IO.succeed(const Logger()));
