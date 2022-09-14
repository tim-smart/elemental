import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:nucleus/nucleus.dart';

Atom<FutureValue<A>, void> streamAtom<A>(
  AtomReader<Stream<A>> create, {
  A? initialValue,
}) =>
    managedAtom<FutureValue<A>>(
      initialValue != null
          ? FutureValue.data(initialValue)
          : FutureValue.loading(),
      (ctx) {
        ctx.onDispose(create(ctx.get)
            .listen((data) => ctx.set(FutureValue.data(data)))
            .cancel);
      },
    );

Tuple2<Atom<FutureValue<A>, void>, Atom<Stream<A>, void>> streamAtomTuple<A>(
  AtomReader<Stream<A>> create, {
  A? initialValue,
  bool? keepAlive,
}) {
  final stream = readOnlyAtom(create).autoDispose();
  final value = streamAtom((get) => get(stream), initialValue: initialValue);

  if (keepAlive == false) {
    value.autoDispose();
  }

  return Tuple2(value, stream);
}
