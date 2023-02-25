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

class Scope with ScopeMixin {
  Scope._(this._closable);

  factory Scope() => Scope._(false);
  factory Scope.closable() => Scope._(true);

  final bool _closable;

  @override
  bool get scopeClosable => _closable;
}

class _ScopeProxy extends Scope {
  _ScopeProxy(this.parent) : super._(parent.scopeClosable);

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
