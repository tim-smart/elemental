import 'package:benchmark_harness/benchmark_harness.dart';

class MsEmitter implements ScoreEmitter {
  @override
  void emit(String testName, double value) {
    final ms = (value / 1000).toStringAsPrecision(4);
    print('$testName(RunTime): $ms ms.');
  }
}

class Benchmark extends AsyncBenchmarkBase {
  Benchmark(String name, this._run) : super(name);

  final Future<void> Function() _run;

  @override
  Future<void> run() => _run();

  @override
  Future<void> exercise() => run();
}

void Function(String, Future<void> Function()) group(
  String group,
) =>
    (name, run) => Benchmark('$group - $name', run).report();
