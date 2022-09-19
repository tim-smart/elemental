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
