part of '../zio.dart';

abstract class Cause<E> {
  const Cause();
  Cause<E2> lift<E2>();
}

class Failure<E> extends Cause<E> {
  const Failure(this.error);
  final E error;

  @override
  Cause<E2> lift<E2>() => throw UnimplementedError();
}

class Defect<E> extends Cause<E> {
  const Defect(this.error, this.stackTrace);
  final dynamic error;
  final StackTrace stackTrace;

  @override
  Cause<E2> lift<E2>() => this as Cause<E2>;
}

class Interrupted<E> extends Cause<E> {
  const Interrupted();

  @override
  Cause<E2> lift<E2>() => this as Cause<E2>;
}

typedef Exit<E, A> = Either<Cause<E>, A>;

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
