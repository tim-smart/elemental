import 'package:flutter/foundation.dart';
import 'package:flutter_nucleus/flutter_nucleus.dart';

/// Create an [AtomWithParent] for a [ChangeNotifier], which exposes a value
/// using the given [select] function.
AtomWithParent<T, Atom<N>> changeNotifierAtom<T, N extends ChangeNotifier>(
  AtomReader<N> create,
  T Function(N notifier) select,
) =>
    atomWithParent(atom((get) {
      final notifier = create(get);
      get.onDispose(notifier.dispose);
      return notifier;
    }), (get, parent) {
      final notifier = get(parent);

      void onChange() => get.setSelf(select(notifier));
      notifier.addListener(onChange);
      get.onDispose(() => notifier.removeListener(onChange));

      return select(notifier);
    });

/// Create an [AtomWithParent] for a [ValueNotifier], which exposes the latest
/// value.
AtomWithParent<T, Atom<N>> valueNotifierAtom<T, N extends ValueNotifier<T>>(
  AtomReader<N> create,
) =>
    changeNotifierAtom(create, (n) => n.value);

/// Create an [Atom] that listens to a [ValueListenable].
ReadOnlyAtom<T> valueListenableAtom<T>(
  ValueListenable<T> Function(AtomContext<T> get) create,
) =>
    atom((get) {
      final listenable = create(get);

      void onChange() => get.setSelf(listenable.value);
      listenable.addListener(onChange);
      get.onDispose(() => listenable.removeListener(onChange));

      return listenable.value;
    });
