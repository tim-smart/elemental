import 'dart:io';

import 'package:flutter_elemental/flutter_elemental.dart';

final flutterLoggerLayer = loggerLayer.replace(IO(() => Logger((message) {
      stderr.writeln(message);
    })));
