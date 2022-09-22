import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_nucleus/flutter_nucleus.dart';

final counter = stateAtom(0);
final multiplied = atom((get) => get(counter) * 10);
final messenger = atom((get) => GlobalKey<ScaffoldMessengerState>());

void main() {
  // (optional) add an AtomScope to the widget tree
  runApp(AtomScope(child: const MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // Use an [AtomBuilder] to rebuild on atom changes.
  @override
  Widget build(BuildContext context) {
    return AtomBuilder((context, watch, child) {
      return MaterialApp(
        scaffoldMessengerKey: watch(messenger),
        title: 'Flutter Demo',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        home: const MyHomePage(title: 'Flutter Demo Home Page'),
      );
    });
  }
}

class MyHomePage extends HookWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  Widget build(BuildContext context) {
    // Or you can use the flutter_hook helpers to watch an atom.
    // [useAtom] returns and listens to atom value changes.
    final count = useAtom(counter);

    // Create a callback function for updating an atom's value.
    final updateCount = context.updateAtom(counter);

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('You have pushed the button this many times:'),
            Text('$count', style: Theme.of(context).textTheme.headline4),
            const Text('Multiplied:'),
            const MultipliedText(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => updateCount((count) => count + 1),
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}

// Use an [AtomBuilder] to fetch the multiplied value
class MultipliedText extends StatelessWidget {
  const MultipliedText({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) =>
      AtomBuilder((context, watch, child) => Text(
            '${watch(multiplied)}',
            style: Theme.of(context).textTheme.headline4,
          ));
}
