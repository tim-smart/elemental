import 'package:dio/dio.dart';
import 'package:elemental/elemental.dart';

/// You could define [Todo] with something like freezed.
typedef Todo = Map<String, dynamic>;

/// Convenience type alias for our ZIO. This allows us to do things like:
///
/// ```dart
/// final greeting = TodosIO.succeed('Hello, world!');
/// ```
///
/// And `greeting` will have the correct type of:
///
/// ```dart
/// ZIO<NoEnv, TodosError, String>
/// ```
typedef TodosIO<A> = ZIO<NoEnv, TodosError, A>;

/// Here we define our error type
abstract class TodosError {}

class ListTodosError extends TodosError {}

class TodosDioError extends TodosError {
  final DioError dioError;
  TodosDioError(this.dioError);

  @override
  String toString() => dioError.toString();
}

// Here we define our service
class Todos {
  const Todos(this.dio);

  final Dio dio;

  TodosIO<IList<Todo>> get list => TodosIO.tryCatch(
        () => dio.get<List<dynamic>>('/todos'),
        (error, stack) => TodosDioError(error),
      )
          .flatMapNullableOrFail(
            (response) => response.data,
            (response) => ListTodosError(),
          )
          .map((todos) => todos.cast<Todo>().toIList());
}

// Here we create a Dio layer, which closes the Dio instance when finished.
final dioLayer = Layer.scoped(
  IO(() {
    print('dio build');
    return Dio(BaseOptions(baseUrl: 'https://jsonplaceholder.typicode.com/'));
  }).acquireRelease(
    (dio) => IO(() {
      print("closed DIO");
      dio.close();
    }).asUnit,
  ),
);

// We then use the Dio layer to create a Todos layer.
final todosLayer = Layer(dioLayer.accessWith((dio) => Todos(dio)));

Future<void> main() async {
  final listAndPrintTodos = TodosIO.layer(todosLayer)
      .zipLeft(ZIO.logInfo('Fetching todos...'))
      .annotateLog("custom key", true) // You can add annotations to the log
      .flatMap((todos) => todos.list)
      .tap(ZIO.logInfo);

  await listAndPrintTodos.runOrThrow();
}
