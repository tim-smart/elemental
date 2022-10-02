part of '../atoms.dart';

/// Represents the `writer` argument to [proxyAtom]
typedef ProxyAtomWriter<R, W> = void Function(
  GetAtom get,
  SetAtom set,
  SetSelf<R> setSelf,
  W value,
);

/// See [proxyAtom].
class ProxyAtomBase<R, W> extends WritableAtom<R, W> {
  ProxyAtomBase(this.reader, this.writer);

  final AtomReader<R> reader;
  final ProxyAtomWriter<R, W> writer;

  @override
  R $read(ctx) => reader(ctx);

  @override
  void $write(GetAtom get, SetAtom set, SetSelf<R> setSelf, W value) {
    writer(get, set, setSelf, value);
  }
}

class ProxyAtom<R, W> extends ProxyAtomBase<R, W>
    with
        AtomConfigMixin<ProxyAtom<R, W>>,
        RefreshableAtomMixin<RefreshableProxyAtom<R, W>> {
  ProxyAtom(super.reader, super.writer);

  @override
  RefreshableProxyAtom<R, W> refreshable() =>
      RefreshableProxyAtom(reader, writer);
}

class RefreshableProxyAtom<R, W> = ProxyAtomBase<R, W>
    with AtomConfigMixin<RefreshableProxyAtom<R, W>>, RefreshableAtom;

/// Creates an [WritableAtom] that can be used to implement custom write logic.
///
/// See [stateAtomWithStorage] for an example, where writes are intercepted and
/// sent to a [NucleusStorage] instance.
ProxyAtom<R, W> proxyAtom<R, W>(
  AtomReader<R> create,
  ProxyAtomWriter<R, W> writer,
) =>
    ProxyAtom(create, writer);
