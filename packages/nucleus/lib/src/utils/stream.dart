import 'package:nucleus/nucleus.dart';

AtomWithParent<FutureValue<A>, Atom<Stream<A>>> streamAtom<A>(
  AtomReader<Stream<A>> create, {
  A? initialValue,
}) =>
    AtomWithParent(
      ReadOnlyAtom((get) => create(get).asBroadcastStream()),
      (get, stream) {
        A? currentData;

        final subscription = get(stream).listen(
          (data) {
            currentData = data;
            get.setSelf(FutureValue.loading(data));
          },
          onError: (err, stackTrace) => get.setSelf(FutureValue.error(
            err,
            stackTrace,
          )),
          onDone: () {
            if (currentData != null) {
              // ignore: null_check_on_nullable_type_parameter
              get.setSelf(FutureValue.data(currentData!));
              currentData = null;
            }
          },
        );

        get.onDispose(subscription.cancel);

        return FutureValue.loading(
          get.previousValue?.dataOrNull ?? initialValue,
        );
      },
    );
