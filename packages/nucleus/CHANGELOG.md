## 0.3.12

- Internal refactor for atom context
- Update benchmarks

## 0.3.11

- Add `filter` to atom extension methods

## 0.3.10

- Revert dependency invalidation changes

## 0.3.9

- Refactor dependency invalidation

## 0.3.8

- Use `Listener` for scheduler

## 0.3.7+1

- Update quick tour for latest changes

## 0.3.7

- Automatically cancel subscriptions when using subscribe with AtomContext

## 0.3.6

- Add weakAtomFamily2
- Add weakAtomFamily3

## 0.3.5

- Change FutureValue extension to target AtomWithParentBase

## 0.3.4+1

- Add install notes to README

## 0.3.4

- Add FutureValue extension methods for atoms without a parent

## 0.3.3

- Relax FutureValue select Parent type

## 0.3.2

- Update FutureValue select method to use AtomWithParent

## 0.3.1

- Update README
- Make base classes abstract

## 0.3.0

- Refactor class hierarchy

## 0.2.3

- Fix util types

## 0.2.2

- Fix atomWithParent propogation

## 0.2.1

- DRY for refreshable atom types

## 0.2.0

- Change configuration methods on atoms to not return void
- Add `RefreshableAtom`, to make `refresh` type safe

## 0.1.39

- Add `rawSelect` to FutureValue extension

## 0.1.38

- Add `get.once` to AtomContext

## 0.1.37

- Add fireImmediately to subscribe on AtomContext

## 0.1.36

- Call `keepAlive()` in `withInitialValue`

## 0.1.35

- Allow refreshSelf even when not externally refreshable

## 0.1.34

- Add refreshSelf to AtomContext

## 0.1.33

- Add `refresh` to registry

## 0.1.32

- Rename `Tuple` to `FamilyArg`

## 0.1.31

- Hide tuple classes from exports

## 0.1.30

- Use `atomWithRefresh` for `futureAtom` and `streamAtom`

## 0.1.29

- Add `combineWith` and `combineWith2` to `FutureValue`.

## 0.1.28+1

- README updates

## 0.1.28

- Improve dependencies performance
- Improve listeners performance

## 0.1.27

- Remove `previousValue`, replace with `get.self()`

## 0.1.26

- Allow overriding the scheduler

## 0.1.25+1

- Add storage examples to the quick tour

## 0.1.25

- add setSelf to ProxyAtom writer

## 0.1.24

- Add `stream` method

## 0.1.23

- Add atomFamily2 and atomFamily3

## 0.1.22

- Improve DX of `FutureValue` `select` and `asyncSelect`

## 0.1.21

- Add `asyncSelect`
- Add extension methods for future and stream atoms

## 0.1.20

- Support `null` in storage
- Refactor invalidation after eager rebuilds

## 0.1.19

- Eagerly rebuild values, to previous un-necessary rebuilds of children.

## 0.1.18

- improve internal readability
- fix previousValue assertion

## 0.1.17

- Internal refactor
- Add `subscribeWithValue`
- Add `atomFamily` to quick tour

## 0.1.16

- Add `weakAtomFamily`
- Add `atomIdMap`

## 0.1.15

- Make `previousValue` on `AtomContext` lazy

## 0.1.14

- Use `Expando` instead of `HashMap`, so we can have weak atom references.

## 0.1.13

- simplify internals

## 0.1.12

- performance improvements

## 0.1.11

- Update quick tour some more
- Internal performance tweaks

## 0.1.10+1

- Start the README quick tour

## 0.1.10

- Improve invalidation performance

## 0.1.9

- Fix orphaned nodes

## 0.1.8

- performance improvements

## 0.1.7

- Fix issue where ReadLifetime was disposed more than once
- Add `name` to `Atom` for debugging

## 0.1.6

- Add `subscribe` to `AtomContext`

## 0.1.5+1

- Remove unused dependencies

## 0.1.5

- Simplify internal dep injection

## 0.1.4

- Prevent duplicate change notifications

## 0.1.3+2

- Update package description

## 0.1.3+1

- More documentation

## 0.1.3

- Add back `Atom.select`
- Fix removal of parent nodes

## 0.1.2

- Fix `notifyListeners` on invalidation

## 0.1.1

- Add back `initialValues`

## 0.1.0

- Replace `Store` with `Registry`

## 0.0.29

- Use `AtomContext` for `atomWithStorage`

## 0.0.28

- Remove `autoDispose`, and make it default

## 0.0.27

- Add `atomWithParent`, and use it for future and stream atoms

## 0.0.26

- Remove `ManagedAtom`, and make `ReadOnlyAtom` more flexible.

## 0.0.25

- Fix keepAlive with future and stream atoms

## 0.0.24

- Don't use `initialValue` from `ManagedAtom` if state already set

## 0.0.23

- Make `ManagedAtom` initialValue lazy

## 0.0.22

- Add `atomWithRefresh` utility

## 0.0.21

- Assume autoDispose if onDispose is used

## 0.0.20

- keepAlive helpers now return void

## 0.0.19

- Fix keepAlive helpers for stream and future atoms

## 0.0.18

- Remove fast immutable collections

## 0.0.17+2

- Update README

## 0.0.17+1

- Update README

## 0.0.17

- performance improvements

## 0.0.16

- Add `onDispose` to read only atoms

## 0.0.15

- `autoDispose` atoms from `select`

## 0.0.14

- Remove depreciated api's
- Add `whenOrElse` to `FutureValue`

## 0.0.13

- Refactor api surface

## 0.0.12

- Fix proxy atom type issues

## 0.0.11

- Add `readOnlyAtomWithStorage`

## 0.0.10

- Add `ProxyAtom`
- Add `atomWithStorage`

## 0.0.9

- Prevent `set` from being called after disposal

## 0.0.8

- Add `select` to `Atom`

## 0.0.7

- Internal refactor

## 0.0.6

- Improve performance

## 0.0.5

- Improve read api

## 0.0.4

- Fix writes and dependencies

## 0.0.3

- Rename `DerivedAtom` to `ReadOnlyAtom`
- Rename `Atom` to `PrimitiveAtom`
- Rename `AtomBase` to `Atom`

## 0.0.2

- Add initial project

## 0.0.1

- Claim package name
