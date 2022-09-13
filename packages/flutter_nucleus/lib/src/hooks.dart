import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_nucleus/flutter_nucleus.dart';

class AtomNotifierWithValue<A> {
  const AtomNotifierWithValue._(this.notifier, this.value);

  final AtomNotifier<A> notifier;
  final A value;
}

AtomNotifier<A> useAtomNotifier<A>(Atom<A> atom) {
  final context = useContext();
  final notifier = useMemoized(
    () => AtomNotifier.from(context, atom),
    [atom],
  );
  useEffect(() => notifier.dispose, [notifier]);
  return notifier;
}

AtomNotifier<A> useAtom<A>(Atom<A> atom) {
  final notifier = useAtomNotifier(atom);
  useListenable(notifier);
  return notifier;
}

A useAtomValue<A>(Atom<A> atom) {
  final notifier = useAtomNotifier(atom);
  return useValueListenable(notifier);
}

void Function(A value) useSetAtom<A>(Atom<A> atom) {
  final notifier = useAtomNotifier(atom);
  void setValue(A value) {
    notifier.value = value;
  }

  return setValue;
}
