import 'dart:async';

import 'package:flutter_elemental/flutter_elemental.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

FutureOr<Exit<E, A>> Function() useZIO<E, A>(
  EIO<E, A> zio,
  List<Object?> keys,
) {
  final context = useContext();
  final runtime = context.getAtom(runtimeAtom);
  return useCallback(() => runtime.run(zio), keys);
}

FutureOr<Exit<E, A>> Function(T _) useZIO1<E, A, T>(
  EIO<E, A> Function(T _) f,
  List<Object?> keys,
) {
  final context = useContext();
  final runtime = context.getAtom(runtimeAtom);
  return useCallback((_) => runtime.run(f(_)), keys);
}

FutureOr<Exit<E, A>> Function(T t, U u) useZIO2<E, A, T, U>(
  EIO<E, A> Function(T t, U u) f,
  List<Object?> keys,
) {
  final context = useContext();
  final runtime = context.getAtom(runtimeAtom);
  return useCallback((t, u) => runtime.run(f(t, u)), keys);
}

ZIORunner<E, A> useZIORunner<E, A>(
  EIO<E, A> zio, {
  List<Object?> keys = const [],
  bool runImmediately = false,
}) {
  final context = useContext();
  final runtime = context.getAtom(runtimeAtom);
  final runner = useMemoized(() => runtime.runSyncOrThrow(zio.runner), keys);
  useEffect(() {
    if (runImmediately) {
      runner.run();
    }
    return runner.dispose;
  }, [runner]);

  return runner;
}
