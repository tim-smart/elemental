import 'package:elemental/elemental.dart';

FutureAtom<A> deferredAtom<A>(Deferred<A> deferred) =>
    futureAtom((get) => deferred.await.runFuture());

ReadOnlyAtom<Ref<A>> refAtom<A>(A a) => atom((get) {
      final scope = Scope.closable();
      get.onDispose(() {
        scope.closeScope.run();
      });
      return Ref.makeScope(a).provide(scope).runSync();
    });
