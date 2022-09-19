import 'package:nucleus/nucleus.dart';

extension AtomExtension<A> on Atom<A> {
  /// Create a derived atom, that ransforms an atoms value using the given
  /// function [f].
  Atom<B> select<B>(B Function(A value) f) =>
      ReadOnlyAtom((get) => f(get(this)));
}
