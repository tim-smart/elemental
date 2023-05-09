import 'dart:async';

import 'package:flutter_elemental/flutter_elemental.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:elemental/elemental.dart';

LayerContext useLayerContext() {
  final context = useMemoized(() => LayerContext());
  useEffect(() => () => context.close<NoEnv, Never>().run(), [context]);
  return context;
}

EIO<E, A> useLayer<E, A>(Layer<E, A> layer) {
  final context = useLayerContext();
  return context.provide(layer);
}

ZIORunnerState<E, A> useLayerRunner<E, A>(Layer<E, A> layer) {
  final eio = useLayer(layer);
  final runner = useZIORunner(eio, keys: [layer], runImmediately: true);
  return runner.state;
}

FutureOr<Exit<E, A>> Function() useZIO<E, A>(
  EIO<E, A> zio, [
  List<Object?> keys = const [],
  bool logFailures = true,
]) {
  final context = useContext();
  final runtime = context.getAtom(runtimeAtom);
  return useCallback(() => runtime.run(logFailures ? zio.logged : zio), keys);
}

FutureOr<Exit<E, A>> Function(T _) useZIO1<E, A, T>(
  EIO<E, A> Function(T _) f, [
  List<Object?> keys = const [],
  bool logFailures = true,
]) {
  final context = useContext();
  final runtime = context.getAtom(runtimeAtom);
  return useCallback(
    (_) => runtime.run(logFailures ? f(_).logged : f(_)),
    keys,
  );
}

FutureOr<Exit<E, A>> Function(T t, U u) useZIO2<E, A, T, U>(
  EIO<E, A> Function(T t, U u) f, [
  List<Object?> keys = const [],
  bool logFailures = true,
]) {
  final context = useContext();
  final runtime = context.getAtom(runtimeAtom);
  return useCallback(
    (t, u) => runtime.run(logFailures ? f(t, u).logged : f(t, u)),
    keys,
  );
}

ZIORunner<E, A> useZIORunner<E, A>(
  EIO<E, A> zio, {
  List<Object?> keys = const [],
  bool runImmediately = false,
}) {
  final context = useContext();
  final runtime = context.getAtom(runtimeAtom);
  final runner = useMemoized(() => runtime.runSyncOrThrow(zio.runner), keys);

  useStream(runner.stream);

  useEffect(() {
    if (runImmediately) {
      runner.run();
    }
    return runner.dispose;
  }, [runner]);

  return runner;
}

A useZIORef<A>(Ref<A> ref) {
  final state = useState(ref.unsafeGet());

  useEffect(() {
    final sub = ref.stream.listen((_) => state.value = _);
    return sub.cancel;
  }, [ref]);

  return state.value;
}
