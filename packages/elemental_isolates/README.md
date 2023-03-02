# elemental isolate runner

Run `ZIO`'s in isolates.

```dart
import 'package:elemental/elemental.dart';
import 'package:elemental_isolates/elemental_isolates.dart';

IO.succeed('Hello from isolate')
  .onIsolate
  .zipRight(IO.logInfo("Back on the main thread!"))
  .run()
```