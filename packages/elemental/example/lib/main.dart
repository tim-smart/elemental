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

  TodosIO<IList<Map<String, dynamic>>> get list => TodosIO.tryCatch(
        () => dio.get<List<dynamic>>('/todos'),
        (error, stack) => TodosDioError(error),
      )
          .flatMapNullableOrFail(
            (response) => response.data,
            (response) => ListTodosError(),
          )
          .map((todos) => todos.cast<Todo>().toIList());
}

// We can turn our service into a Layer, which wraps the nucleus dependency
// management tool.
final dioAtom = atom(
  (get) => Dio(BaseOptions(baseUrl: 'https://jsonplaceholder.typicode.com/')),
);

final todosLayer = Layer(ZIO.service(dioAtom).map((dio) => Todos(dio)));

Future<void> main() async {
  final listTodos = ZIO
      .layer(todosLayer)
      .zipLeft(ZIO.logInfo('Fetching todos...'))
      .liftError<TodosError>()
      .flatMap((todos) => todos.list);

  final todos = await listTodos.run();

  print(todos);
}
