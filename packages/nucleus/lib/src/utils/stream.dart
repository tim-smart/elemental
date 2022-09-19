import 'package:nucleus/nucleus.dart';

AtomWithParent<FutureValue<A>, Atom<Stream<A>>> streamAtom<A>(
  AtomReader<Stream<A>> create, {
  A? initialValue,
}) =>
    AtomWithParent(
      ReadOnlyAtom((get) => create(get).asBroadcastStream()),
      (_, stream) {
        A? currentData;

        _.onDispose(_(stream)
            .listen(
              (data) {
                currentData = data;
                _.setSelf(FutureValue.loading(data));
              },
              onError: (err, stackTrace) => _.setSelf(FutureValue.error(
                err,
                stackTrace,
              )),
              onDone: () {
                if (currentData != null) {
                  // ignore: null_check_on_nullable_type_parameter
                  _.setSelf(FutureValue.data(currentData!));
                  currentData = null;
                }
              },
            )
            .cancel);

        return FutureValue.loading(_.previousValue?.dataOrNull ?? initialValue);
      },
    );
