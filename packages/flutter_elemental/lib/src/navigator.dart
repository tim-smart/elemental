import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_elemental/flutter_elemental.dart';

extension ElementalNavigatorExt on NavigatorState {
  IOOption<A> zio<A>(FutureOr<A?> Function(NavigatorState _) f) =>
      IOOption.tryCatchNullable(() => f(this));

  IOOption<A> pushIO<A>(Route<A> route) =>
      IOOption.tryCatchNullable(() => push(route));
}
