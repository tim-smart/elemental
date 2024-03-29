import 'dart:isolate';

import 'package:elemental/elemental.dart';
// ignore: implementation_imports
import 'package:elemental/src/future_or.dart';

typedef Request<I, E, O> = (I, Deferred<E, O>);
typedef _RequestWithPort<I> = (I, SendPort);

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
      isolate.addErrorListener(exitPort.sendPort);

      final waitForExit = _IsolateIO.future(() => exitPort.first)
          .flatMap((_) => _IsolateIO<Never>.fail(IsolateError(_)));

      final activeRequests = <Request<I, E, O>>{};

      _IsolateIO<Unit> sendRequest(
        Request<I, E, O> request,
      ) =>
          _IsolateIO<ReceivePort>(() {
            activeRequests.add(request);
            final receive = ReceivePort();
            sendPort.send((request.$1, receive.sendPort));
            return receive;
          })
              .flatMapThrowable(
                (_) => _.first,
                (error, stack) => IsolateError(error),
              )
              .zipLeft(ZIO(() => activeRequests.remove(request)))
              .flatMap(
            (_) {
              return (_ as Exit<dynamic, dynamic>).match(
                (cause) => request.$2.failCause(cause.lift()),
                (value) => request.$2.complete(value),
              );
            },
          );

      final send = requests
          .take<Scope<NoEnv>, IsolateError>()
          .flatMap((_) => sendRequest(_))
          .forever;

      await $(
        send.race(waitForExit).tapExit((exit) => ZIO(() {
              for (final request in activeRequests) {
                request.$2.unsafeCompleteExit(exit.mapLeft(
                  (_) => _.when<Cause<E>>(
                    failure: (_) => Defect.current(_.error),
                    defect: (_) => _.lift(),
                    interrupted: (_) => _.lift(),
                  ),
                ));
              }
              activeRequests.clear();
            })),
      );
    });

void Function(SendPort) _entrypoint<I, E, O>(IsolateHandler<I, E, O> handle) =>
    (sendPort) async {
      final receivePort = ReceivePort();
      sendPort.send(receivePort.sendPort);

      await for (final _RequestWithPort<I> request in receivePort) {
        handle(request.$1).run().then(request.$2.send);
      }
    };
