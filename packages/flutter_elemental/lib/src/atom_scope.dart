import 'package:flutter/widgets.dart';
import 'package:flutter_elemental/flutter_elemental.dart';

Future<AtomScope> atomScopeWithLayers(
  Iterable<Layer> layers, {
  List<AtomInitialValue> initialValues = const [],
  Key? key,
  required Widget child,
}) =>
    Layer.buildAll(
      layers,
      initialValues: initialValues,
    ).map((r) => AtomScope.withRegistry(r, key: key, child: child)).runFuture();
