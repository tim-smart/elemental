import 'dart:isolate';

import 'package:elemental/elemental.dart';

typedef Request<I, E, O> = Tuple2<I, Deferred<E, O>>;
typedef _RequestWithPort<I> = Tuple2<I, SendPort>;

typedef IsolateHandler<I, E, O> = EIO<E, O> Function(I input);
typedef _IsolateIO<A> = ZIO<Scope<NoEnv>, IsolateError, A>;

class IsolateError {
  const IsolateError(this.error);
  final dynamic error;

  @override
  String toString() => "IsolateError($error)";
}

ZIO<Scope<NoEnv>, IsolateError, Never> spawnIsolate<I, E, O>(
  IsolateHandler<I, E, O> handle,
  Dequeue<Request<I, E, O>> requests,
) =>
    _IsolateIO<Never>.Do(($, env) async {
      final receivePort = ReceivePort();
      final isolate = await $(
        _IsolateIO<Isolate>.future(
          () => Isolate.spawn<SendPort>(
            _entrypoint<I, E, O>(handle),
            receivePort.sendPort,
          ),
        ).acquireRelease((_) => IO(_.kill).asUnit),
      );

      final SendPort sendPort = await receivePort.first;
      final exitPort = ReceivePort();
      isolate.addOnExitListener(exitPort.sendPort);

      final waitForExit = _IsolateIO.future(() => exitPort.first)
          .zipRight(_IsolateIO<Never>.fail(IsolateError("exit")));

      _IsolateIO<Unit> sendRequest(
        Request<I, E, O> request,
      ) =>
          _IsolateIO<ReceivePort>(() {
            final receive = ReceivePort();
            sendPort.send(tuple2(request.first, receive.sendPort));
            return receive;
          })
              .flatMapThrowable(
                (_) => _.first,
                (error, stack) => IsolateError(error),
              )
              .flatMap((_) => request.second.completeExit(_));

      final send = requests
          .take<Scope<NoEnv>, IsolateError>()
          .flatMap((_) => sendRequest(_))
          .forever;

      await $(send.race(waitForExit));
    });

void Function(SendPort) _entrypoint<I, E, O>(IsolateHandler<I, E, O> handle) =>
    (sendPort) async {
      final receivePort = ReceivePort();
      sendPort.send(receivePort.sendPort);

      await for (final _RequestWithPort<I> request in receivePort) {
        final exit = await handle(request.first).run();
        request.second.send(exit);
      }
    };
