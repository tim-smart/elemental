import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:nucleus/nucleus.dart';

Atom<FutureValue<A>> streamAtom<A>(
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

Tuple2<Atom<FutureValue<A>>, Atom<Stream<A>>> streamAtomTuple<A>(
  AtomReader<Stream<A>> create, {
  A? initialValue,
  bool? keepAlive,
}) {
  final stream = atom(create).autoDispose();
  final value = streamAtom((get) => get(stream), initialValue: initialValue);

  if (keepAlive == false) {
    value.autoDispose();
  }

  return Tuple2(value, stream);
}
