part of '../zio.dart';

enum LogLevel {
  debug(0, "DEBUG"),
  info(1, "INFO"),
  warn(2, "WARN"),
  error(3, "ERROR");

  const LogLevel(this.priority, this.label);

  final int priority;
  final String label;

  operator <(LogLevel other) => priority < other.priority;
  operator <=(LogLevel other) => priority <= other.priority;
  operator >(LogLevel other) => priority > other.priority;
  operator >=(LogLevel other) => priority >= other.priority;
}

final logLevelLayer = Layer(IO.succeed(LogLevel.info));

class Logger {
  IO<Unit> log(LogLevel level, String message) =>
      IO.layer(logLevelLayer).flatMap(
            (currentLevel) => level < currentLevel
                ? IO.unit()
                : IO(() {
                    print("${level.label}: $message");
                    return unit;
                  }),
          );

  IO<Unit> debug(String message) => log(LogLevel.debug, message);
  IO<Unit> info(String message) => log(LogLevel.info, message);
  IO<Unit> warn(String message) => log(LogLevel.warn, message);
  IO<Unit> error(String message) => log(LogLevel.error, message);
}

final loggerLayer = Layer(IO(() => Logger()));