import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:nucleus/nucleus.dart';

Atom<FutureValue<A>> streamAtom<A>(
  AtomReader<Stream<A>> create, {
  A? initialValue,
  bool? keepAlive,
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
      keepAlive: keepAlive,
    );

Tuple2<Atom<FutureValue<A>>, Atom<Stream<A>>> streamAtomTuple<A>(
  AtomReader<Stream<A>> create, {
  A? initialValue,
  bool? keepAlive,
}) {
  final stream = readOnlyAtom(create, keepAlive: keepAlive);
  final value = streamAtom(
    (get) => get(stream),
    initialValue: initialValue,
    keepAlive: keepAlive,
  );
  return Tuple2(value, stream);
}
