# nucleus

An atomic dependency and state management toolkit.

## Design goals

- Simplicity - simple API with no surprises
- Performance - allow for millions of `Atom`'s without a high penalty
- Composability - make it easy to create your own functionality

## A quick tour

The first thing you might need in your Flutter app is some shared state.

With nucleus, you can use a `stateAtom` to achieve this.

### stateAtom

First define your atom, in this case we want to represent the state of a counter.

```dart
final counter = stateAtom(0);
```

By default, all atom's are created **lazily** (only when they are used) and are
**automatically disposed** when they are no longer needed.

If you want to disable the automatic disposal of your atom, then call `keepAlive()`:

```dart
final counter = stateAtom(0).keepAlive();
```

We can then use the `AtomBuilder` widget from the `flutter_nucleus` package to
listen for changes to our counter:

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

Or if you are using `flutter_hooks`, you can `useAtom`:

```dart
class CounterText extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final count = useAtom(counter);
    return Text(count.toString());
  }
}
```

### flutter_nucleus `BuildContext` methods

You can then update the counter state by using the `updateAtom` method, which is
added to the `BuildContext` with an extension.

This creates an updater function which you can use in your widgets:

```dart
class CounterButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final updateCount = context.updateAtom(counter);

    return ElevatedButton(
      onPressed: () {
        updateCount((count) => count + 1);
      },
      child: const Text("Increment"),
    );
  }
}
```

Other methods on `BuilderContext` include:

- `getAtom` - for reading an atom once.

- `setAtom` - similar to `updateAtom`, but allows you to set the atom value
  directly.

  ```dart
  final setCount = context.setAtom(counter);

  // ...

  setCount(2); // Sets the value of the counter atom to 2.
  ```

- `registry` - access the `AtomRegistry` directly

  ```dart
  final registry = context.registry(listen: true);
  ```

### atom

We can now create and track some shared state in our app, but now we might want
to create derived state from other atoms.

A common use for this is dependency injection. First we can define our shared
dependency:

```dart
final httpClient = atom((get) => MyHttpClient());
```

> It is worth noting that `atom` creates a read-only atom (the type is
> `ReadOnlyAtom<T>`). Earlier `stateAtom(0)` created a `WritableAtom<int, int>`
> (the first generic type is the **read** type, the second is the **write** type).

Now we can create our derived atom:

```dart
final userRepository = atom((get) => UserRepository(
  httpClient: get(httpClient), // Here we are accessing another atom within our atom
));
```

If the `httpClient` ever changed, then our `userRepository` would also re-create
itself.

If you want to allow your atom to be refreshed / rebuilt externally, then call
`.refreshable()` (similar to `.keepAlive()`):

```dart
final userRepository = atom((get) => UserRepository(
  httpClient: get(httpClient), // Here we are accessing another atom within our atom
)).refreshable();

// then using a BuildContext:

context.refreshAtom(userRepository);
```

The `get` parameter is actually an `AtomContext` instance, which also has some
other helpful methods attached. View them all here:

https://pub.dev/documentation/nucleus/latest/nucleus/AtomContext-class.html#instance-methods

---

At this point, with `stateAtom` and `atom` you probably have all you need to
build a simple stateful app. But what about `async` / `await` and `Stream`?

### futureAtom

If you need to work with `Future`'s in your app (which pretty much every app does!), then `futureAtom` makes it easy.

Earlier we created a `userRepository` atom, let's use that to fetch some users:

```dart
final allUsers = futureAtom((get) => get(usersRepository).fetchAll());
```

A `futureAtom` gives us back a `FutureValue<T>`, which can then be used in your widgets:

```dart
@override
Widget build(BuildContext context) => AtomBuilder((context, watch, child) {
  final users = watch(allUsers);

  return users.when(
    data: (users) => UserList(users: users),
    loading: (previousData) => LoadingIndicator(),
    error: (err, stackTrace) => ErrorMessage(error: err),
  );
});
```

As you can see, `FutureValue` allows us to write async code is an easy to understand way. It has a couple of other methods to aid us too, take a look here:

https://pub.dev/documentation/nucleus/latest/nucleus/FutureValue-class.html#instance-methods

> Need to access the actual `Future`?
>
> `futureAtom` uses [`atomWithParent`](#atomWithParent) in its implementation ([take a look](https://pub.dev/documentation/nucleus/latest/nucleus/futureAtom.html#source)), which exposes the `Future` through the `.parent` property. Here we `await` the `allUsers` future, and return a count of the results.
>
> ```dart
> final userCount = futureAtom((get) async {
>   final users = await get(allUsers.parent);
>   return users.length;
> });
> ```

### streamAtom

Similar to `futureAtom`, `streamAtom` turns a `Stream` into a `FutureValue` containing the latest value.

```dart
final latestUser = streamAtom((get) => get(userRepository).latestUserStream());
```

You can then use it in your widgets:

```dart
@override
Widget build(BuildContext context) => AtomBuilder((context, watch, child) {
  final userState = watch(latestUser);

  // `dataOrNull` will be `null` until we first receive some data.
  final user = userState.dataOrNull;

  // `isLoading` will be `true`, until the `Stream` completes.
  final isLoading = userState.isLoading;

  if (user == null) {
    return LoadingIndicator();
  }

  return UserProfile(
    user: user,
    isLoading: isLoading,
  );
});
```

The underlying `Stream` is available through `latestUser.parent`.

### atomWithParent

Both `futureAtom` and `streamAtom` use `atomWithParent` to tie the state with
the thing that generates it.

You can use this pattern too! Lets create our own custom atom type for using a
`ValueNotifier` from the flutter SDK. It will:

- Correctly dispose the notifier when done
- Correctly remove listeners
- Allow us to directly access the notifier so we can set its value

```dart
AtomWithParent<T, Atom<ValueNotifier<T>>> valueNotifierAtom<T>(
  AtomReader<ValueNotifier<T>> create,
) =>
    atomWithParent(atom((get) {
      final notifier = create(get);
      get.onDispose(notifier.dispose);
      return notifier;
    }), (get, parent) {
      final notifier = get(parent);

      void handler() {
        get.setSelf(notifier.value);
      }

      notifier.addListemer(handler);
      get.onDispose(() => notifier.removeListener(handler));

      return notifier.value;
    });
```

Now lets use it.

```dart
final counter = valueNotifierAtom((get) => ValueNotifier(0));

// ... in your widgets

// Watch the current count
watch(counter);

// Update the notifier value
context.getAtom(counter.parent).value = 123;
```

We can now get the current count by watching `counter`, and access the notifier through `counter.parent`.

We just implemented our own custom atom type! I hope this shows you just how composable atoms can be.

### atomFamily

If you ever need to group atoms together, then you can use `atomFamily`.

Lets say you wanted to fetch a user by their ID number, and wanted to represent
this as an atom. You need a way to pass in the `id` parameter.

Using our `userRepository` from earlier, this is how you would do it with
`atomFamily`:

```dart
final userById = atomFamily((int id) {
  return futureAtom((get) => get(userRepository).fetchUser(id));
});
```

Now in your widgets, you can use the atom just like another [`futureAtom`](#futureAtom):

```dart
@override
Widget build(BuildContext context) {
  return AtomBuilder((context, watch, child) {
    final futureValue = watch(userById(userId));

    return futureValue.when(
      data: (user) => UserProfile(user: user),
      loading: (previousData) => LoadingIndicator(),
      error: (err, stackTrace) => ErrorMessage(error: err),
    );
  });
}
```

### stateAtomWithStorage

Have a `stateAtom`, but want to make sure it is persisted between app restarts? Then you can use `stateAtomWithStorage`.

First, you need to define your `NucleusStorage` atom. Let's use the `SharedPrefsStorage` implementation from the `flutter_nucleus` package.

```dart
/// This atom will eventually hold our [SharedPreferences] instance.
/// We need to make sure we call `keepAlive` so it doesn't get automatically
/// disposed.
final sharedPrefsAtom = atom<SharedPreferences>((get) => throw UnimplementedError()).keepAlive();

/// This atom will eventually hold our [SharedPrefsStorage] instance, which
/// implements [NucleusStorage].
final sharedPrefsStorage = atom((get) => SharedPrefsStorage(get(sharedPrefsAtom)));

void main() async {
  // Build our [SharedPreferences] instance
  final sharedPrefs = await SharedPreferences.build();

  return runApp(AtomScope(
    // Pass the instance to [initialValues]
    initialValues: [sharedPrefsAtom.withInitialValue(sharedPrefs)],
    child: const YourApp(),
  ));
}
```

Now instead of using `stateAtom`, we can use `stateAtomWithStorage`:

```dart
final counter = stateAtomWithStorage(
  0,
  storage: sharedPrefsStorage, // Atom we defined earlier
  key: 'counter', // Unique string key

  // Override these depending on your state model
  fromJson: (json) => json as int,
  toJson: (count) => count,
);
```

### atomWithStorage

For more advanced usage of persistence, you can use `atomWithStorage`.

Let's use our [`valueNotiferAtom`](#atomWithParent) from earlier, and add persistence support!

```dart
AtomWithParent<T, Atom<ValueNotifier<T>>> valueNotifierAtomWithStorage<T>(
  ValueNotifier<T> Function(
    AtomContext<ValueNotifier<T>> get,
    T? initialValue,
  ) create, {
  required String key,
  required T Function(dynamic) fromJson,
  required dynamic Function(T) toJson,
}) =>
    // Use `atomWithStorage` for the parent atom
    atomWithParent(atomWithStorage(
      (get, read, write) {
        // Create the notifier, potentially using the stored value
        final notifier = create(get, read());

        // Add a listener to persist the value to storage
        notifier.addListener(() {
          write(notifier.value);
        });

        get.onDispose(notifier.dispose);
        return notifier;
      },
      key: key,
      fromJson: fromJson,
      toJson: toJson,

      // We will use the `NucleusStorage` atom from the `stateAtomWithStorage`
      // example
      storage: sharedPrefsStorage,
    ), (get, parent) {
      final notifier = get(parent);

      void handler() {
        get.setSelf(notifier.value);
      }

      notifier.addListemer(handler);
      get.onDispose(() => notifier.removeListener(handler));

      return notifier.value;
    });
```

Then we can use it, and the counter will not reset back to `0` after the app
restarts:

```dart
final counter = valueNotifierAtomWithStorage(
  (get, int? initialValue) => ValueNotifier(initialValue ?? 0),
  key: 'counter',
  toJson: (count) => count,
  fromJson: (json) => json as int,
);

// ... in your widgets

// Watch the current count
watch(counter);

// Update the notifier value
context.getAtom(counter.parent).value = 123;
```

### writableAtom

TODO

Until some docs are written, take a look at the `stateAtomWithStorage`
implementation:

https://pub.dev/documentation/nucleus/latest/nucleus/stateAtomWithStorage.html#source

`writableAtom` gives you full access to the atom read / write API surface.
