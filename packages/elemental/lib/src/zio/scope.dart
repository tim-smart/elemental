part of '../zio.dart';

mixin ScopeMixin {
  bool get scopeClosable => false;

  final _scopeFinalizers = <IO<Unit>>[];

  IO<Unit> addScopeFinalizer(IO<Unit> finalizer) => IO(() {
        _scopeFinalizers.add(finalizer);
        return unit;
      });

  IO<Unit> get closeScope => IO.collectPar(_scopeFinalizers).zipRight(IO(() {
        _scopeFinalizers.clear();
        return unit;
      }));
}

class Scope with ScopeMixin {
  Scope._(this._closable);

  factory Scope() => Scope._(false);
  factory Scope.closable() => Scope._(true);

  final bool _closable;

  @override
  bool get scopeClosable => _closable;
}
