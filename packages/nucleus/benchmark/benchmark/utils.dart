import 'package:benchmark_harness/benchmark_harness.dart';

class MsEmitter implements ScoreEmitter {
  @override
  void emit(String testName, double value) {
    final ms = (value / 1000).toStringAsPrecision(4);
    print('$testName(RunTime): $ms ms.');
  }
}

class Benchmark<Acc> extends BenchmarkBase {
  Benchmark(String name, this._setup, this._run)
      : super(name, emitter: MsEmitter());

  final Acc Function() _setup;
  late final Acc _acc;
  final void Function(Acc) _run;

  @override
  void setup() {
    _acc = _setup();
  }

  @override
  void run() {
    _run(_acc);
  }

  @override
  void exercise() => run();
}

void Function(String, void Function(Acc)) group<Acc>(
  String group,
  Acc Function() setup,
) =>
    (name, run) => Benchmark<Acc>('$group - $name', setup, run).report();
