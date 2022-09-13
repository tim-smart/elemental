import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_nucleus/flutter_nucleus.dart';
import 'package:nucleus/nucleus.dart';

AtomNotifier<A> useAtomNotifier<A>(AtomBase<A> atom) {
  final context = useContext();
  final notifier = useMemoized(
    () => AtomNotifier.from(context, atom),
    [atom],
  );
  useEffect(() => notifier.dispose, [notifier]);
  return notifier;
}

A useAtomValue<A>(AtomBase<A> atom) {
  final notifier = useAtomNotifier(atom);
  return useValueListenable(notifier);
}

void Function(A value) useSetAtom<A>(AtomBase<A> atom) {
  final notifier = useAtomNotifier(atom);
  void setValue(A value) {
    notifier.value = value;
  }

  return setValue;
}
