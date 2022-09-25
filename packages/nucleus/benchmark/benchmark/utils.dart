import 'package:benchmark_harness/benchmark_harness.dart';

class Benchmark<Acc> extends BenchmarkBase {
  Benchmark(String name, this._setup, this._run) : super(name);

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
