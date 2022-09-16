import 'package:nucleus/nucleus.dart';

AtomWithParent<FutureValue<A>, Atom<Stream<A>>> streamAtom<A>(
  AtomReader<Stream<A>> create, {
  A? initialValue,
}) =>
    AtomWithParent(
      ReadOnlyAtom((get) => create(get).asBroadcastStream()),
      (_, stream) {
        _.onDispose(_(stream)
            .listen((data) => _.setSelf(FutureValue.data(data)))
            .cancel);

        final previous = _.previousValue;
        if (previous is FutureData<A>) {
          return FutureValue.loading(previous.data);
        }

        return initialValue != null
            ? FutureValue.data(initialValue)
            : FutureValue.loading();
      },
    );
