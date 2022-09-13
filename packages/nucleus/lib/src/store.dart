import 'dart:async';
import 'dart:collection';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';

import './atoms.dart';

class AtomState {
  AtomState({
    required this.value,
    required this.revision,
    required this.valid,
    this.dependencies = const IMapConst({}),
    List<void Function()>? disposers,
  }) : disposers = disposers ?? [];

  final Object? value;
  final int revision;
  final bool valid;
  final IMap<AtomBase, int> dependencies;
  final List<void Function()> disposers;

  void onDispose() {
    for (final fn in disposers) {
      fn();
    }
  }

  @override
  String toString() =>
      'AtomState(value: $value, revision: $revision, valid: $valid)';

  AtomState copyWith({
    Object? value,
    int? revision,
    bool? valid,
    IMap<AtomBase, int>? dependencies,
  }) =>
      AtomState(
        value: value ?? this.value,
        revision: revision ?? this.revision,
        valid: valid ?? this.valid,
        dependencies: dependencies ?? this.dependencies,
        disposers: disposers,
      );

  @override
  operator ==(Object? other) =>
      other is AtomState &&
      other.value == value &&
      other.revision == revision &&
      other.valid == valid &&
      other.dependencies == dependencies;

  @override
  int get hashCode => Object.hash(
        runtimeType,
        value,
        revision,
        valid,
        dependencies,
      );
}

class AtomMount {
  AtomMount(this.atom);

  final AtomBase atom;
  final List<void Function()> listeners = [];
  final Set<AtomBase> dependants = {};

  bool get isUnmountable =>
      listeners.isEmpty &&
      (dependants.isEmpty ||
          (dependants.length == 1 && dependants.contains(atom)));
}

class Store {
  Store({
    List<AtomInitialValue> initialValues = const [],
  }) {
    for (final value in initialValues) {
      _put(value.first, value.second);
    }
  }

  final Map<AtomBase, AtomState> _atomStateMap = HashMap();
  final Map<AtomBase, AtomMount> _atomMountedMap = HashMap();

  Future<void>? _schedulerFuture;
  final _atomsScheduledForRemoval = <AtomBase>{};

  // === Public api
  Value read<Value>(AtomBase<Value> atom) {
    if (!_atomMountedMap.containsKey(atom)) {
      throw ArgumentError.value(
        atom,
        "atom",
        "has to be mounted to be read. Try calling subscribe first.",
      );
    }
    return _read(atom).value as Value;
  }

  void put<Value>(
    AtomBase<Value> atom,
    Value value,
  ) {
    if (atom is! Atom<Value>) {
      throw ArgumentError.value(
        atom,
        "atom",
        "You can not write to DerivedAtom or WritableAtom",
      );
    }

    _put(atom, value);
  }

  void Function() subscribe(
    AtomBase atom,
    void Function() onChange,
  ) {
    final mount = _ensureMounted(atom);
    mount.listeners.add(onChange);

    return () {
      mount.listeners.remove(onChange);
      _unmountAtom(atom);
    };
  }

  Future<R> use<R>(AtomBase atom, FutureOr<R> Function() f) async {
    final mount = _ensureMounted(atom);

    try {
      return await f();
    } finally {
      _unmount(mount);
    }
  }

  // === Internal api
  AtomMount _ensureMounted(AtomBase atom) {
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

  void _unmountAtom(AtomBase atom) {
    final mount = _atomMountedMap[atom];
    if (mount != null) {
      _unmount(mount);
    }
  }

  void _unmount(AtomMount mount) {
    if (!mount.isUnmountable) {
      return;
    }

    _atomMountedMap.remove(atom);

    final state = _atomStateMap[atom];

    if (state == null) {
      return;
    }

    _maybeScheduleAtomRemoval(mount.atom);

    // dependants
    for (final dep in state.dependencies.keys) {
      if (dep == mount.atom) continue;

      final depMount = _atomMountedMap[dep];
      if (depMount == null) continue;

      depMount.dependants.remove(atom);
      _unmount(depMount);
    }
  }

  AtomState _read(AtomBase atom) {
    final currentState = _atomStateMap[atom];

    if (currentState != null) {
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
      final depsAreSame = currentState.dependencies
          .everyEntry((e) => _atomStateMap[e.key]?.revision == e.value);

      if (depsAreSame) {
        if (!currentState.valid) {
          return currentState.copyWith(valid: true);
        }

        return currentState;
      }
    }

    // Needs recomputation
    final usedDeps = <AtomBase>{};
    final getter = _buildGetter(atom, usedDeps);
    final value = atom.read(getter);

    if (atom is ManagedAtom) {
      currentState?.onDispose();

      final disposers = <void Function()>[];
      atom.create(
        get: getter,
        set: _buildSetter(atom, usedDeps, disposers),
        onDispose: disposers.add,
        previous: currentState?.value ?? value,
      );

      return _atomStateMap[atom] ??
          _put(
            atom,
            value,
            dependencies: usedDeps,
            disposers: disposers,
          );
    }

    return _put(atom, value, dependencies: usedDeps);
  }

  IMap<AtomBase, int> _createDependencies(
    IMap<AtomBase, int> previous,
    Set<AtomBase>? toAdd,
  ) {
    if (toAdd == null) {
      return previous;
    }

    var merged = IMap<AtomBase, int>();

    for (final dep in toAdd) {
      final state = _atomStateMap[dep];
      merged = merged.add(dep, state?.revision ?? 0);
    }

    return merged;
  }

  AtomGetter _buildGetter(AtomBase parent, Set<AtomBase> usedDeps) =>
      <Value>(dep) {
        usedDeps.add(dep);
        final state = dep == parent ? _atomStateMap[dep] : _read(dep);

        if (state != null) {
          return state.value as Value;
        }

        if (dep is Atom<Value>) {
          return dep.initialValue;
        } else if (dep is ManagedAtom<Value>) {
          return dep.initialValue;
        }

        throw UnsupportedError("Atom has no state");
      };

  void Function(Value value) _buildSetter<Value>(
    AtomBase<Value> atom,
    Set<AtomBase> dependencies,
    List<void Function()> disposers,
  ) =>
      (value) {
        _put(
          atom,
          value,
          dependencies: dependencies,
          disposers: disposers,
        );
      };

  AtomState _put(
    AtomBase atom,
    Object? value, {
    Set<AtomBase>? dependencies,
    List<void Function()>? disposers,
  }) {
    final currentState = _atomStateMap[atom];

    final deps = _createDependencies(
      currentState?.dependencies ?? const IMapConst({}),
      dependencies,
    );

    // Bump revision if value has changed
    final revision =
        (currentState?.revision ?? 0) + (value != currentState?.value ? 1 : 0);

    final nextState = AtomState(
      value: value,
      revision: revision,
      valid: true,
      dependencies: deps.containsKey(atom) ? deps.add(atom, revision) : deps,
      disposers: disposers,
    );

    if (currentState == nextState) {
      return currentState!;
    }

    _atomStateMap[atom] = nextState;

    _invalidateDependants(atom);

    final listeners = _atomMountedMap[atom]?.listeners;
    if (listeners != null) {
      for (final l in listeners) {
        l();
      }
    }

    return nextState;
  }

  void _invalidateDependants(AtomBase atom) {
    final dependants = _atomMountedMap[atom]?.dependants;
    if (dependants == null) {
      return;
    }

    for (final dep in dependants) {
      if (dep == atom) continue;

      _atomStateMap.update(dep, (s) => s.copyWith(valid: false));
      _invalidateDependants(dep);
    }
  }

  // ==== Scheduler
  void _runScheduledTasks() {
    _schedulerFuture = null;

    for (final atom in _atomsScheduledForRemoval) {
      if (_atomMountedMap.containsKey(atom)) continue;
      _atomStateMap[atom]?.onDispose();
      _atomStateMap.remove(atom);
    }
    _atomsScheduledForRemoval.clear();
  }

  void _maybeScheduleAtomRemoval(AtomBase atom) {
    if (atom.keepAlive) {
      return;
    }

    _atomsScheduledForRemoval.add(atom);
    _schedulerFuture ??= Future.microtask(_runScheduledTasks);
  }
}
