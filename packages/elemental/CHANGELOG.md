## 0.0.68

- Change `envWithZIO` signature

## 0.0.67

- log* accept Object?
- Add `logOrElse`

## 0.0.66

- Option.flatMapNullable
- Option.flatMapThrowable

## 0.0.65

- Add error channel to Deferred
- Add ZIOQueue

## 0.0.64

- Improve layer API

## 0.0.63

- memoize Layer by default

## 0.0.62

- Improve zioRunAtomSync error
- Add more access methods to Layer

## 0.0.61

- Use broadcast stream for Ref

## 0.0.60

- `Layer.access`

## 0.0.59

- Make `zioRunAtom` sync

## 0.0.58

- zioRefAtom

## 0.0.57

- `orDie`

## 0.0.56

- Add unsafeValueDidChange to Ref

## 0.0.55

- Add Layer.toString

## 0.0.54

- Drop `AtomRegistry` dependency
- `Layer` improvements
- Add `ZIOContext`
- Improve `Schedule`

## 0.0.53

- lint fixes
- NoValue type for IOOption
- getters

## 0.0.52

- `fromNullable*`

## 0.0.51

- Add const `unit`

## 0.0.50

- export atoms

## 0.0.49

- Add back atoms

## 0.0.48

- Add AtomContext helpers

## 0.0.47

- lift() fixes

## 0.0.46

- `tapErrorCause`

## 0.0.45

- Better defect detection

## 0.0.44

- add `either`

## 0.0.43

- add interruption support

## 0.0.42

- Add back tryCatchOption

## 0.0.41

- Revert to factories and remove *Lift constructors

## 0.0.40

- Fix sleep return type

## 0.0.39

- Add missing lift()

## 0.0.38

- Fix lifting

## 0.0.37

- runtime provideLayer

## 0.0.36

- Drop dart:io dependency

## 0.0.35

- Add tryCatchOption

## 0.0.34

- Update function parameter names to _

## 0.0.33

- Add discard variants to collect

## 0.0.32

- Add `toZIOOrFail` to Option

## 0.0.31

- Add `toZIO` to Option and Either

## 0.0.30

- Log to stderr

## 0.0.29

- Add extract helpers for Maps

## 0.0.28

- unitF -> unitLift

## 0.0.27

- Add Lift variants of constructors

## 0.0.26

- Add Iterable extension

## 0.0.25

- Fix `unit` usage

## 0.0.24

- Make `unit` final

## 0.0.23

- Add lift to RIO

## 0.0.22

- Add `liftError` to `EIO`
- Reduce use of `factory`

## 0.0.21

- Add `unsafeGet` to `Ref`

## 0.0.20

- `ZIO.envWith*`

## 0.0.19

- `Runtime.withLayers` takes an optional `registry`

## 0.0.18

- `Layer.replace` returns another `Layer`

## 0.0.17

- `Runtime`
- `Logger`
- Better `Layer` / dependency management

## 0.0.16

- \*Env combinators
- defect combinators
- flatMap2

## 0.0.15

- Only allow `runSync` on `IO`

## 0.0.14

- Release scope even on defects

## 0.0.13

- Add `option` to `OptionRIO`

## 0.0.12

- Add compose and pipe

## 0.0.11

- Add refAtomWithStorage

## 0.0.10

- Add `ignore` and `ignoreLogged`

## 0.0.9

- Add `refAtomWithStorage`

## 0.0.8

- Add `refAtom` and `deferredAtom`

## 0.0.7

- Use dynamic for errors

## 0.0.6

- Add Layer.scope

## 0.0.5

- runFutureEither

## 0.0.4

- narrow static methods

## 0.0.3

- Export more from fpdart

## 0.0.1

- Claim package name
