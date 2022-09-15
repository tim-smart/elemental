import 'package:nucleus/nucleus.dart';

class StreamAtom<A> extends ManagedAtom<FutureValue<A>> {
  StreamAtom(
    AtomReader<Stream<A>> create, {
    A? initialValue,
  })  : stream = ReadOnlyAtom(
          (get, onDispose) => create(get, onDispose).asBroadcastStream(),
        ).autoDispose(),
        super(
          initialValue != null
              ? FutureValue.data(initialValue)
              : FutureValue.loading(),
          (x) {},
        );

  final Atom<Stream<A>> stream;

  @override
  StreamAtom<A> keepAlive() => super.keepAlive() as StreamAtom<A>;
  @override
  StreamAtom<A> autoDispose() => super.autoDispose() as StreamAtom<A>;

  @override
  void create({
    required AtomGetter get,
    required void Function(FutureValue<A>) set,
    required void Function(void Function()) onDispose,
    required FutureValue<A> previous,
  }) {
    onDispose(get(stream).listen((data) => set(FutureValue.data(data))).cancel);
  }
}

StreamAtom<A> streamAtom<A>(
  AtomReader<Stream<A>> create, {
  A? initialValue,
}) =>
    StreamAtom(create, initialValue: initialValue);
