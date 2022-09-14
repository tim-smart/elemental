# nucleus

An atomic state management library for dart.

## Design goals

- Simplicity - simple API with no surprises
- Performance - allow for millions of `Atom`'s without a high penalty
- Composability - make it easy to create your own functionality

## Quick example

An example using the `flutter_nucleus` package.

First declare your atoms:

```dart
final counter = stateAtom(0);
```

Then use them in your widgets:

```dart
class CounterText extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AtomBuilder((context, watch, child) {
      final count = watch(counter);
      return Text(count.toString());
    });
  }
}
```

Or if you are using `flutter_hooks`:

```dart
class CounterText extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final count = useAtom(counter);
    return Text(count.toString());
  }
}
```
