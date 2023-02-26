part of '../zio.dart';

/// The result of a [ZIO] computation.
///
/// [Exit] is an [Either] with a left side (failure) of [Cause] and a right side (success) of [A].
typedef Exit<E, A> = Either<Cause<E>, A>;

/// Represents the error channel of a [ZIO].
///
/// A [ZIO] can fail with a [Failure], a [Defect] or be [Interrupted].
abstract class Cause<E> {
  const Cause();

  StackTrace? get stackTrace;
  final stackTraceSkipFrames = 2;

  String prettyStackTrace([String prefix = ""]) {
    if (stackTrace == null) {
      return "";
    }

    return prefix +
        stackTrace.toString().split('\n').skip(stackTraceSkipFrames).join('\n');
  }

  Cause<E2> lift<E2>();

  B when<B>({
    required B Function(Failure<E> _) failure,
    required B Function(Defect<E> _) defect,
    required B Function(Interrupted<E> _) interrupted,
  });

  Cause<E> withTrace(StackTrace stack);
}

/// Represents a failure with an error of type [E].
class Failure<E> extends Cause<E> {
  const Failure(this.error, [this.stackTrace]);

  final E error;

  @override
  final StackTrace? stackTrace;

  @override
  Cause<E2> lift<E2>() => throw UnimplementedError();

  @override
  B when<B>({
    required B Function(Failure<E> _) failure,
    required B Function(Defect<E> _) defect,
    required B Function(Interrupted<E> _) interrupted,
  }) {
    return failure(this);
  }

  @override
  Failure<E> withTrace(StackTrace stack) =>
      stackTrace == null ? Failure(error, stack) : this;

  @override
  String toString() => 'Failure($error)${prettyStackTrace("\n Stack: ")}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Failure &&
          runtimeType == other.runtimeType &&
          error == other.error;

  @override
  int get hashCode => error.hashCode;
}

/// Represents an uncaught error.
class Defect<E> extends Cause<E> {
  const Defect(this.error, this.defectStackTrace, [this.stackTrace]);

  factory Defect.current(dynamic error, [StackTrace? stackTrace]) =>
      Defect(error, StackTrace.current, stackTrace);

  final dynamic error;
  final StackTrace defectStackTrace;

  @override
  final StackTrace? stackTrace;

  @override
  Cause<E2> lift<E2>() => Defect(error, defectStackTrace, stackTrace);

  @override
  B when<B>({
    required B Function(Failure<E> _) failure,
    required B Function(Defect<E> _) defect,
    required B Function(Interrupted<E> _) interrupted,
  }) {
    return defect(this);
  }

  @override
  Defect<E> withTrace(StackTrace stack) =>
      stackTrace == null ? Defect(error, defectStackTrace, stack) : this;

  @override
  String prettyStackTrace([String prefix = ""]) {
    if (stackTrace == null) {
      return prefix + defectStackTrace.toString();
    }

    return super.prettyStackTrace(prefix);
  }

  @override
  String toString() => 'Defect($error)${prettyStackTrace("\n Stack: ")})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Defect &&
          runtimeType == other.runtimeType &&
          error == other.error;

  @override
  int get hashCode => error.hashCode;
}

/// [Interrupted] is used to indicated that a [ZIO] was interrupted.
class Interrupted<E> extends Cause<E> {
  Interrupted([this.stackTrace]);

  @override
  final StackTrace? stackTrace;

  @override
  Cause<E2> lift<E2>() => Interrupted(stackTrace);

  @override
  B when<B>({
    required B Function(Failure<E> _) failure,
    required B Function(Defect<E> _) defect,
    required B Function(Interrupted<E> _) interrupted,
  }) {
    return interrupted(this);
  }

  @override
  Interrupted<E> withTrace(StackTrace stack) =>
      stackTrace == null ? Interrupted(stack) : this;

  @override
  String toString() => 'Interrupted()${prettyStackTrace("\n Stack: ")}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Interrupted && runtimeType == other.runtimeType;

  @override
  int get hashCode => 0;
}

extension EitherExitExt<E, A> on Either<E, A> {
  Exit<E, A> toExit() => mapLeft(Failure.new);
}

extension ExitExt<E, A> on Exit<E, A> {
  Exit<E, B> flatMapExit<B>(Exit<E, B> Function(A _) f) => flatMap(f);

  Exit<E, B> flatMapExitEither<B>(Either<E, B> Function(A _) f) =>
      flatMap((_) => f(_).toExit());

  Exit<E2, A> liftExit<E2>() => mapLeft((a) => a.lift());

  Exit<E2, A> mapFailure<E2>(E2 Function(E _) f) =>
      mapLeft((_) => _ is Failure<E> ? Failure(f(_.error)) : _.lift());

  FutureOr<Exit<E2, B>> _matchExitFOr<E2, B>(
    FutureOr<Exit<E2, B>> Function(E _) onFailure,
    FutureOr<Exit<E2, B>> Function(A _) onSuccess,
  ) =>
      match(
        (_) => _ is Failure<E> ? onFailure(_.error) : Either.left(_.lift()),
        (_) => onSuccess(_),
      );

  Exit<E2, B> matchExit<E2, B>(
    Either<E2, B> Function(E _) onFailure,
    Either<E2, B> Function(A _) onSuccess,
  ) =>
      match(
        (_) => _ is Failure<E>
            ? onFailure(_.error).toExit()
            : Either.left(_.lift()),
        (_) => onSuccess(_).toExit(),
      );
}
