part of '../zio.dart';

mixin ScopeMixin {
  bool get scopeClosable => false;

  final _scopeFinalizers = <IO<Unit>>[];

  ZIO<R, E, Unit> addScopeFinalizer<R, E>(IO<Unit> finalizer) => ZIO(() {
        _scopeFinalizers.add(finalizer);
        return unit;
      });

  ZIO<R, E, Unit> removeScopeFinalizer<R, E>(IO<Unit> finalizer) => ZIO(() {
        _scopeFinalizers.remove(finalizer);
        return unit;
      });

  ZIO<R, E, Unit> closeScope<R, E>() =>
      _scopeFinalizers.reversed.collectDiscard.zipRight(IO(() {
        _scopeFinalizers.clear();
        return unit;
      })).lift();

  late final IO<Unit> closeScopeIO = closeScope();
}

class Scope<R> with ScopeMixin {
  Scope._(this.env, this._closable);

  static Scope<NoEnv> noEnv() => Scope._(const NoEnv(), false);
  static Scope<NoEnv> closable() => Scope._(const NoEnv(), true);

  factory Scope.withEnv(R env) => Scope._(env, false);
  factory Scope.withEnvClosable(R env) => Scope._(env, true);

  final bool _closable;
  final R env;

  @override
  bool get scopeClosable => _closable;
}

class _ScopeProxy extends Scope<NoEnv> {
  _ScopeProxy(this.parent) : super._(const NoEnv(), parent.scopeClosable);

  final ScopeMixin parent;

  @override
  ZIO<R, E, Unit> addScopeFinalizer<R, E>(IO<Unit> finalizer) =>
      parent.addScopeFinalizer(finalizer);

  @override
  ZIO<R, E, Unit> removeScopeFinalizer<R, E>(IO<Unit> finalizer) =>
      parent.removeScopeFinalizer(finalizer);

  @override
  ZIO<R, E, Unit> closeScope<R, E>() => parent.closeScope();
}
