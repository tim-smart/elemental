# nucleus

An atomic state management library for dart.

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
final counter = stateAtom(0)..keepAlive();
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

- `subscribeAtom` - listen to changes of an atom. Returns a function for
  removing the listener.

  ```dart
  final unsubscribe = context.subscribeAtom(counter, () {
    print(context.getAtom(counter));
  });

  unsubscribe(); // remove the listener
  ```

- `mountAtom` - similar to `subscribeAtom`, except it doesn't take a listener.

  ```dart
  final unmount = context.mountAtom(counter);

  // It is now guaranteed that the `counter` atom is active in the registry.
  // To remove it (if there are no other listeners):

  unmount();
  ```

### atom

We can now create and track some shared state in our app, but now we might want
to create derived state from other atoms.

A common use for this is dependency injection. First we can define our shared
dependency:

```dart
final httpClient = atom((get) => MyHttpClient());
```

> It is worth noting that `atom` creates a read-only atom (the type is `Atom<T>`).
> Earlier, `stateAtom(0)` created a `WritableAtom<int, int>` (the first generic
> type is the **read** type, the second is the **write** type).

Now we can create our derived atom:

```dart
final userRepository = atom((get) => UserRepository(
  httpClient: get(httpClient), // Here we are accessing another atom within our atom
));
```

If the `httpClient` ever changed, then our `userRepository` would also re-create
itself.

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

Now in your widgets, you can use the atom just like another (`futureAtom`)[#futureAtom]:

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

### proxyAtom

TODO

### stateAtomWithStorage

TODO

### atomWithStorage

TODO

### atomWithRefresh

TODO
