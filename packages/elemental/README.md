<h3 align="center">
  <img src="https://user-images.githubusercontent.com/40680/219979601-724793d8-513d-4196-93b8-db5c1872c240.png" width="700">
</h3>

<p align="center">
A toolkit for writing software in dart
</p>

Includes:

- `ZIO` a building block for writing effectful programs. Explore the full API: https://pub.dev/documentation/elemental/latest/elemental/ZIO-class.html
- `Layer` for composing dependencies
- `nucleus`, a simple state and dependency management tool. See more here: [https://pub.dev/packages/nucleus](https://pub.dev/packages/nucleus)
- Thanks to the `fpdart` package [https://pub.dev/packages/fpdart](https://pub.dev/packages/fpdart):
  - `Option`
  - `Either`
- Immutable data structures, thanks to [https://pub.dev/packages/fast_immutable_collections](https://pub.dev/packages/fast_immutable_collections)

## Usage

The `ZIO<R, E, A>` type represents an synchronous or asynchronous operation.

- The `R` generic is for representing the requirements / environment
- The `E` generic is for representing errors
- The `A` generic is for the success type

There are a handful of helpful methods to ease composition!


```dart
import 'package:elemental/elemental.dart';

ZIO<NoEnv, Never, String> greeting(String name) => ZIO(() => "Hello $name!")

// Note `ZIO<NoEnv, Never, String>` can be shortened to `IO<String>`.

// Here we create a simple wrapper around `print`
IO<Unit> log(String message) => IO(() => print(message)).asUnit;

// And compose them together!
greeting.tap(log).run();
```

It is worth noting that the above will run synchronously. Only when you start
using `Future`'s in your program, will things run asynchronously.

### Layers

A quick intro to services and layers can be found in `example/`.
