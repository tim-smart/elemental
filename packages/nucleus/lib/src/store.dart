import 'dart:async';
import 'dart:collection';
import 'package:collection/collection.dart';

import './atoms.dart';

class Store {
  Store({
    List<AtomInitialValue> initialValues = const [],

    /// For testing only
    HashMap<Atom, AtomState>? stateMap,

    /// For testing only
    HashMap<Atom, AtomMount>? mountMap,
  })  : _atomStateMap = stateMap ?? HashMap(),
        _atomMountedMap = mountMap ?? HashMap() {
    for (final iv in initialValues) {
      _put(iv.atom, iv.value);
    }
  }

  final HashMap<Atom, AtomState> _atomStateMap;
  final HashMap<Atom, AtomMount> _atomMountedMap;

  var _pendingWrites = HashMap<Atom, AtomState?>();

  Future<void>? _schedulerFuture;
  final _atomsScheduledForRemoval = <Atom>[];

  // === Public api
  Value read<Value>(Atom<Value> atom) => _read(atom).value as Value;

  void put<Value>(WritableAtom<dynamic, Value> atom, Value value) {
    atom.write(this, _setValue, value);
    _flushPending();
  }

  void Function() subscribe(Atom atom, void Function() onChange) {
    final mount = _ensureMounted(atom);
    mount.listeners.add(onChange);

    return () {
      mount.listeners.remove(onChange);
      _maybeUnmount(mount);
    };
  }

  Future<R> use<R>(Atom atom, FutureOr<R> Function() f) async {
    final unmount = mount(atom);

    try {
      return await f();
    } finally {
      unmount();
    }
  }

  void Function() mount(Atom atom) => subscribe(atom, () {
        _read(atom);
      });

  // === Internal api
  void _setValue<W>(WritableAtom<dynamic, W> atom, W value) {
    _put(atom, value);
  }

  void _setState(Atom atom, AtomState state, AtomState? previousState) {
    _atomStateMap[atom] = state;
    _pendingWrites.putIfAbsent(atom, () => previousState);
    _maybeScheduleAtomRemoval(atom, state);
  }

  AtomMount _ensureMounted(Atom atom) {
    var mount = _atomMountedMap[atom];
    if (mount != null) {
      return mount;
    }

    mount = AtomMount(atom);
    _atomMountedMap[atom] = mount;

    final state = _read(atom);

    for (final dep in state.dependencies.keys) {
      _ensureMounted(dep).dependants.add(atom);
    }

    return mount;
  }

  void _maybeUnmount(AtomMount mount) {
    if (!mount.isUnmountable) {
      return;
    }

    final atom = mount.atom;

    _atomMountedMap.remove(atom);

    final state = _atomStateMap[atom];
    if (state == null) {
      return;
    }

    _maybeScheduleAtomRemoval(atom, state, true);

    // dependants
    for (final dep in state.dependencies.keys) {
      if (dep == atom) continue;

      final depMount = _atomMountedMap[dep];
      if (depMount == null) continue;

      depMount.dependants.remove(atom);
      _maybeUnmount(depMount);
    }
  }

  AtomState _read(Atom atom) {
    final currentState = _atomStateMap[atom];

    if (currentState != null) {
      // We might not need to check dependencies
      if (currentState.hasNoDependenciesExcept(atom)) {
        return currentState;
      }

      // Maybe update dependencies.
      // Increments the dependency revision on change.
      for (final dep in currentState.dependencies.keys) {
        if (dep == atom) continue;

        if (_atomMountedMap.containsKey(dep)) {
          final depState = _atomStateMap[dep];
          if (!(depState?.valid == true)) {
            _read(dep);
          }
        } else {
          _read(dep);
        }
      }

      // If any dep revision is different, recompute.
      final depsAreSame = currentState.dependencies.entries
          .every((e) => _atomStateMap[e.key]?.revision == e.value);

      if (depsAreSame) {
        if (!currentState.valid) {
          return currentState.copyWith(valid: true);
        }

        return currentState;
      }
    }

    // Needs recomputation
    currentState?.context.dispose();

    final ctx = ReadContext(this, atom, currentState?.value);
    final value = atom.$read(ctx);

    return ctx.calledSetSelf
        ? _atomStateMap[atom]!
        : _put(
            atom,
            value,
            context: ctx,
          );
  }

  HashMap<Atom, int> _createDependencies(
    HashMap<Atom, int> previous,
    HashSet<Atom>? toAdd,
  ) {
    if (toAdd == null) {
      return previous;
    }

    var merged = HashMap<Atom, int>();

    for (final dep in toAdd) {
      final state = _atomStateMap[dep];
      merged[dep] = state?.revision ?? 0;
    }

    return merged;
  }

  AtomState _put(
    Atom atom,
    Object? value, {
    ReadContext? context,
  }) {
    final currentState = _atomStateMap[atom];

    // Bump revision if value has changed
    final revision =
        (currentState?.revision ?? 0) + (value != currentState?.value ? 1 : 0);

    final deps = _createDependencies(
      currentState?.dependencies ?? HashMap(),
      context?.deps,
    );

    if (deps.containsKey(atom)) {
      deps[atom] = revision;
    }

    final nextState = AtomState(
      value: value,
      revision: revision,
      valid: true,
      dependencies: deps,
      keepAliveOverride: atom.keepAliveOverride,
      context:
          context ?? currentState?.context ?? ReadContext(this, atom, null),
    );

    if (currentState == nextState) {
      return currentState!;
    }

    _setState(atom, nextState, currentState);
    _invalidateDependants(atom);

    return nextState;
  }

  void _invalidateDependants(Atom atom) {
    final dependants = _atomMountedMap[atom]?.dependants;
    if (dependants == null) {
      return;
    }

    for (final dep in dependants) {
      if (dep == atom) continue;

      final state = _atomStateMap[dep];
      if (state != null) {
        state.context.dispose();
        _setState(dep, state.copyWith(valid: false), state);
      }

      _invalidateDependants(dep);
    }
  }

  // ==== Pending writes
  void _flushPending() {
    while (_pendingWrites.isNotEmpty) {
      final pending = _pendingWrites;
      _pendingWrites = HashMap();

      for (final e in pending.entries) {
        final atom = e.key;
        final previousState = e.value;
        final currentState = _atomStateMap[atom];

        if (currentState != null &&
            currentState.value != previousState?.value) {
          _mountDependencies(atom, currentState, previousState?.dependencies);
        }

        if (previousState?.valid == false && currentState?.valid == true) {
          continue;
        }

        final mount = _atomMountedMap[atom];
        if (mount != null) {
          for (final fn in mount.listeners) {
            fn();
          }
        }
      }
    }
  }

  void _mountDependencies(
    Atom atom,
    AtomState state,
    HashMap<Atom, int>? previousDependencies,
  ) {
    final ignored = HashSet<Atom>();

    if (previousDependencies != null) {
      for (final dep in previousDependencies.keys) {
        if (state.dependencies.containsKey(dep)) {
          // Not changed
          ignored.add(dep);
          continue;
        }

        final mount = _atomMountedMap[dep];
        if (mount != null) {
          mount.dependants.remove(atom);
          _maybeUnmount(mount);
        }
      }
    }

    for (final dep in state.dependencies.keys) {
      if (ignored.contains(dep)) continue;

      final mount = _atomMountedMap[dep];

      if (mount != null) {
        mount.dependants.add(atom);
      } else if (_atomMountedMap.containsKey(atom)) {
        _ensureMounted(dep).dependants.add(atom);
      }
    }
  }

  // ==== Scheduler

  void _runScheduledTasks() {
    _schedulerFuture = null;

    for (final atom in _atomsScheduledForRemoval) {
      if (_atomMountedMap.containsKey(atom)) continue;
      _atomStateMap[atom]?.context.dispose();
      _atomStateMap.remove(atom);
    }
    _atomsScheduledForRemoval.clear();
  }

  void _maybeScheduleAtomRemoval(
    Atom atom,
    AtomState state, [
    bool skipMountCheck = false,
  ]) {
    if (state.keepAlive ||
        (!skipMountCheck && _atomMountedMap.containsKey(atom))) {
      return;
    }

    _atomsScheduledForRemoval.add(atom);
    _schedulerFuture ??= Future.microtask(_runScheduledTasks);
  }
}

class AtomState {
  AtomState({
    required this.value,
    required this.revision,
    required this.valid,
    required this.dependencies,
    required this.keepAliveOverride,
    required this.context,
  });

  final Object? value;
  final int revision;
  final bool valid;
  final HashMap<Atom, int> dependencies;
  ReadContext context;

  final bool? keepAliveOverride;
  late final keepAlive = keepAliveOverride ?? context.disposers.isEmpty;

  bool hasNoDependenciesExcept(Atom atom) =>
      dependencies.isEmpty ||
      (dependencies.length == 1 && dependencies.containsKey(atom));

  @override
  String toString() =>
      'AtomState(value: $value, revision: $revision, valid: $valid)';

  AtomState copyWith({
    Object? value,
    int? revision,
    bool? valid,
    HashMap<Atom, int>? dependencies,
    ReadContext? context,
  }) =>
      AtomState(
        value: value ?? this.value,
        revision: revision ?? this.revision,
        valid: valid ?? this.valid,
        dependencies: dependencies ?? this.dependencies,
        keepAliveOverride: keepAliveOverride,
        context: context ?? this.context,
      );

  static const _dependencyEquality = MapEquality<Atom, int>();

  @override
  operator ==(Object? other) =>
      other is AtomState &&
      other.value == value &&
      other.revision == revision &&
      other.valid == valid &&
      _dependencyEquality.equals(other.dependencies, dependencies);

  @override
  int get hashCode => Object.hash(
        runtimeType,
        value,
        revision,
        valid,
        _dependencyEquality.hash(dependencies),
      );
}

class AtomMount {
  AtomMount(this.atom);

  final Atom atom;
  final listeners = <void Function()>[];
  final dependants = HashSet<Atom>();

  bool get isUnmountable =>
      listeners.isEmpty &&
      (dependants.isEmpty ||
          (dependants.length == 1 && dependants.contains(atom)));
}

class ReadContext implements AtomContext<dynamic> {
  ReadContext(this.store, this.atom, this.previousValue);

  final Store store;
  final Atom atom;
  final deps = HashSet<Atom>();
  final disposers = <void Function()>[];
  var _disposed = false;
  var calledSetSelf = false;

  @override
  final Object? previousValue;

  @override
  void onDispose(void Function() fn) => disposers.add(fn);

  void dispose() {
    _disposed = true;
    if (disposers.isEmpty) return;

    for (final fn in disposers) {
      fn();
    }
    disposers.clear();
  }

  @override
  Value call<Value>(Atom<Value> dep) {
    deps.add(dep);

    final state = dep == atom ? store._atomStateMap[dep] : store._read(dep);

    if (state != null) {
      return state.value as Value;
    }

    if (dep is StateAtom<Value>) {
      return dep.initialValue;
    }

    throw UnsupportedError("has no state");
  }

  @override
  void set<Value>(WritableAtom<dynamic, Value> atom, Value value) =>
      store.put(atom, value);

  @override
  void setSelf(Object? value) {
    calledSetSelf = true;

    if (_disposed) {
      throw UnsupportedError('can not set a disposed atom');
    }

    store._put(
      atom,
      value,
      context: this,
    );
    store._flushPending();
  }
}
