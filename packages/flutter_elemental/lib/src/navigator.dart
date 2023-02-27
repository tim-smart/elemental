import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_elemental/flutter_elemental.dart';

extension ElementalNavigatorExt on NavigatorState {
  BuildContextIOOption<A> zio<A>(FutureOr<A?> Function(NavigatorState _) f) =>
      zioNoContext(f).lift();

  BuildContextIOOption<A> pushIO<A>(Route<A> route) =>
      pushIONoContext(route).lift();

  IOOption<A> zioNoContext<A>(FutureOr<A?> Function(NavigatorState _) f) =>
      ZIO.tryCatchNullable(() => f(this));

  IOOption<A> pushIONoContext<A>(Route<A> route) =>
      ZIO.tryCatchNullable(() => push(route));
}
