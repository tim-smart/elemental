import 'package:nucleus/nucleus.dart';

class StreamAtom<A> extends Atom<FutureValue<A>> {
  StreamAtom(
    AtomReader<Stream<A>> create, {
    this.initialValue,
  }) : stream = ReadOnlyAtom((get) => create(get).asBroadcastStream())
          ..autoDispose() {
    keepAlive();
  }

  final Atom<Stream<A>> stream;
  final A? initialValue;

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
  FutureValue<A> read(_) {
    _.onDispose(
        _(stream).listen((data) => _.setSelf(FutureValue.data(data))).cancel);

    return initialValue != null
        ? FutureValue.data(initialValue!)
        : FutureValue.loading();
  }
}

StreamAtom<A> streamAtom<A>(
  AtomReader<Stream<A>> create, {
  A? initialValue,
}) =>
    StreamAtom(create, initialValue: initialValue);
