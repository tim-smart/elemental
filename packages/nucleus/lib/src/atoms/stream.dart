import 'package:nucleus/nucleus.dart';

class StreamAtom<A> extends ManagedAtom<FutureValue<A>> {
  StreamAtom(
    AtomReader<Stream<A>> create, {
    A? initialValue,
  })  : stream = ReadOnlyAtom(
          (get, onDispose) => create(get, onDispose).asBroadcastStream(),
        )..autoDispose(),
        super(
          () => initialValue != null
              ? FutureValue.data(initialValue)
              : FutureValue.loading(),
          (x) {},
        ) {
    keepAlive();
  }

  final Atom<Stream<A>> stream;

  @override
  void keepAlive() {
    stream.keepAlive();
    super.keepAlive();
  }

  @override
  void autoDispose() {
    stream.autoDispose();
    super.autoDispose();
  }

  @override
  void create({
    required AtomGetter get,
    required void Function(FutureValue<A>) set,
    required void Function(void Function()) onDispose,
    required FutureValue<A>? previousValue,
  }) {
    onDispose(get(stream).listen((data) => set(FutureValue.data(data))).cancel);
  }
}

StreamAtom<A> streamAtom<A>(
  AtomReader<Stream<A>> create, {
  A? initialValue,
}) =>
    StreamAtom(create, initialValue: initialValue);
