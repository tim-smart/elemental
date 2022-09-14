import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_nucleus/flutter_nucleus.dart';

final counterAtom = atom(0);
final multiplied = readOnlyAtom((get) => get(counterAtom) * 10);
final messenger = readOnlyAtom((_) => GlobalKey<ScaffoldMessengerState>());

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Use an [AtomBuilder] to rebuild on atom changes.
    return AtomBuilder((context, get, child) => MaterialApp(
          scaffoldMessengerKey: get(messenger).value,
          title: 'Flutter Demo',
          theme: ThemeData(
            primarySwatch: Colors.blue,
          ),
          home: const MyHomePage(title: 'Flutter Demo Home Page'),
        ));
  }
}

class MyHomePage extends HookWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  Widget build(BuildContext context) {
    // Or you can use the flutter_hook helpers to watch an atom.
    // [useAtom] returns an [AtomNotifier] and also listens for changes.
    final counter = useAtom(counterAtom);

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('You have pushed the button this many times:'),
            Text(
              '${counter.value}',
              style: Theme.of(context).textTheme.headline4,
            ),
            const Text('Multiplied:'),
            const MultipliedText(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => counter.update((a) => a + 1),
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
      AtomBuilder((context, get, child) => Text(
            '${get(multiplied).value}',
            style: Theme.of(context).textTheme.headline4,
          ));
}
