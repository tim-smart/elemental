part of '../zio.dart';

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

final logLevelLayer = Layer(IO.succeed(LogLevel.info));

void _printStdout(String message) => print(message);

class Logger {
  Logger([this._print = _printStdout]);

  final void Function(String message) _print;

  IO<Unit> log(LogLevel level, String message) =>
      IO.layer(logLevelLayer).flatMap(
            (currentLevel) => level < currentLevel
                ? IO.unitIO
                : IO(() {
                    _print("${level.label}: $message");
                    return unit;
                  }),
          );

  IO<Unit> debug(String message) => log(LogLevel.debug, message);
  IO<Unit> info(String message) => log(LogLevel.info, message);
  IO<Unit> warn(String message) => log(LogLevel.warn, message);
  IO<Unit> error(String message) => log(LogLevel.error, message);
}

final loggerLayer = Layer(IO(() => Logger()));
