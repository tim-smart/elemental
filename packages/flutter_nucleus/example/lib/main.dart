import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_nucleus/flutter_nucleus.dart';

final counter = stateAtom(0);
final multiplied = atom((get) => get(counter) * 10);
final messenger = atom((get) => GlobalKey<ScaffoldMessengerState>());

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // add an AtomScope to the widget tree
  runApp(AtomScope(child: const MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // Use an [AtomBuilder] to rebuild on atom changes.
  @override
  Widget build(BuildContext context) {
    return AtomBuilder((context, get, child) {
      return MaterialApp(
        scaffoldMessengerKey: get(messenger),
        title: 'Flutter Demo',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        home: const MyHomePage(title: 'Flutter Demo Home Page'),
      );
    });
  }
}

class CounterText extends HookWidget {
  const CounterText({super.key});

  @override
  Widget build(BuildContext context) {
    // Or you can use the flutter_hook helpers to watch an atom.
    // [useAtom] returns and listens to atom value changes.
    final count = useAtom(counter);

    return Text('$count', style: Theme.of(context).textTheme.headlineMedium);
  }
}

class CounterButton extends StatelessWidget {
  const CounterButton({super.key});
  @override
  Widget build(BuildContext context) {
    // Create a function for updating the counter's value.
    final updateCount = context.updateAtom(counter);

    return FloatingActionButton(
      onPressed: () => updateCount((count) => count + 1),
      tooltip: 'Increment',
      child: const Icon(Icons.add),
    );
  }
}

// Use an [AtomBuilder] to fetch the multiplied value
class MultipliedText extends StatelessWidget {
  const MultipliedText({
    Key? key,
    this.suffix = '',
  }) : super(key: key);

  final String suffix;

  @override
  Widget build(BuildContext context) =>
      AtomBuilder((context, get, child) => Text(
            '${get(multiplied)}$suffix',
            style: Theme.of(context).textTheme.headlineMedium,
          ));
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('You have pushed the button this many times:'),
            CounterText(),
            Text('Multiplied:'),
            MultipliedText(),
          ],
        ),
      ),
      floatingActionButton: const CounterButton(),
    );
  }
}
