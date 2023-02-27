import 'package:flutter/widgets.dart';
import 'package:flutter_elemental/flutter_elemental.dart';

/// A [ZIO] that requires a [BuildContext] to run.
typedef BuildContextEIO<E, A> = ZIO<BuildContext, E, A>;

/// A [ZIO] that requires a [BuildContext] to run, and never fails.
typedef BuildContextIO<A> = ZIO<BuildContext, Never, A>;

/// A [ZIO] that requires a [BuildContext] to run, and has an optional value.
typedef BuildContextIOOption<A> = RIOOption<BuildContext, A>;

extension ZIOBuildContextExt<R, E, A> on ZIO<R, E, A> {
  ZIO<R, E, A> provideRegistryRuntime(AtomRegistry registry) =>
      withRuntime(registry.get(runtimeAtom));

  ZIO<R, E, A> provideBuildContextRuntime(BuildContext context) =>
      provideRegistryRuntime(context.registry(listen: false));
}

extension ZIOBuildContextEnvExt<E, A> on EIO<E, A> {
  BuildContextEIO<E, A> get withBuildContextRuntime => ZIO.from(
        (ctx) => provideBuildContextRuntime(ctx.env).unsafeRun(ctx.noEnv),
      );

  ZIO<AtomRegistry, E, A> get withRegistryRuntime => ZIO.from(
        (ctx) => provideRegistryRuntime(ctx.env).unsafeRun(ctx.noEnv),
      );
}
