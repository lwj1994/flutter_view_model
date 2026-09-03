import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:view_model/view_model.dart';

const int _consumerCount = 100;
const int _warmupFrames = 10;
const int _sampleFrames = 120;

enum _ConsumerMode { broad, selector }

enum _ChangeKind { relevant, irrelevant, idle }

class _Scenario {
  const _Scenario({
    required this.name,
    required this.consumerMode,
    required this.changeKind,
  });

  final String name;
  final _ConsumerMode consumerMode;
  final _ChangeKind changeKind;

  String get performanceKey => 'frame_$name';

  bool get shouldRebuildConsumers =>
      changeKind != _ChangeKind.idle &&
      (consumerMode == _ConsumerMode.broad ||
          changeKind == _ChangeKind.relevant);
}

const List<_Scenario> _scenarios = <_Scenario>[
  _Scenario(
    name: 'idle_100',
    consumerMode: _ConsumerMode.selector,
    changeKind: _ChangeKind.idle,
  ),
  _Scenario(
    name: 'broad_relevant_100',
    consumerMode: _ConsumerMode.broad,
    changeKind: _ChangeKind.relevant,
  ),
  _Scenario(
    name: 'broad_irrelevant_100',
    consumerMode: _ConsumerMode.broad,
    changeKind: _ChangeKind.irrelevant,
  ),
  _Scenario(
    name: 'selector_relevant_100',
    consumerMode: _ConsumerMode.selector,
    changeKind: _ChangeKind.relevant,
  ),
  _Scenario(
    name: 'selector_irrelevant_100',
    consumerMode: _ConsumerMode.selector,
    changeKind: _ChangeKind.irrelevant,
  ),
];

class WidgetFrameScenarioResult {
  WidgetFrameScenarioResult({
    required this.name,
    required this.performanceKey,
    required this.consumerMode,
    required this.changeKind,
    required this.actualConsumerBuilds,
    required this.expectedConsumerBuilds,
    required this.pumpTimesUs,
  });

  final String name;
  final String performanceKey;
  final String consumerMode;
  final String changeKind;
  final int actualConsumerBuilds;
  final int expectedConsumerBuilds;
  final List<double> pumpTimesUs;

  double get medianPumpMs => _percentile(pumpTimesUs, 0.50) / 1000;

  double get p90PumpMs => _percentile(pumpTimesUs, 0.90) / 1000;

  double get p99PumpMs => _percentile(pumpTimesUs, 0.99) / 1000;

  Map<String, Object?> toJson() => <String, Object?>{
    'name': name,
    'performanceKey': performanceKey,
    'consumerMode': consumerMode,
    'changeKind': changeKind,
    'consumerCount': _consumerCount,
    'warmupFrames': _warmupFrames,
    'sampleFrames': _sampleFrames,
    'actualConsumerBuilds': actualConsumerBuilds,
    'expectedConsumerBuilds': expectedConsumerBuilds,
    'buildsPerSampleFrame': actualConsumerBuilds / _sampleFrames,
    'medianPumpTimeMs': medianPumpMs,
    'p90PumpTimeMs': p90PumpMs,
    'p99PumpTimeMs': p99PumpMs,
    'pumpTimesUs': pumpTimesUs,
  };
}

class WidgetFrameBenchmarkReport {
  WidgetFrameBenchmarkReport({
    required this.scenarios,
    required this.correctnessChecks,
  });

  final List<WidgetFrameScenarioResult> scenarios;
  final Map<String, bool> correctnessChecks;

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': 1,
    'generatedAt': DateTime.now().toUtc().toIso8601String(),
    'environment': <String, Object?>{
      'buildMode': kProfileMode
          ? 'profile'
          : kReleaseMode
          ? 'release'
          : 'debug',
      'platform': Platform.operatingSystem,
      'platformVersion': Platform.operatingSystemVersion,
      'hostName': Platform.localHostname,
      'flutterVersion': FlutterVersion.version,
      'flutterRevision': FlutterVersion.frameworkRevision,
      'dartVersion': FlutterVersion.dartVersion ?? Platform.version,
      'consumerCount': _consumerCount,
      'warmupFrames': _warmupFrames,
      'sampleFrames': _sampleFrames,
    },
    'correctnessChecks': correctnessChecks,
    'scenarios': scenarios.map((value) => value.toJson()).toList(),
  };
}

class WidgetFrameBenchmark {
  WidgetFrameBenchmark({required this.binding, required this.tester});

  final IntegrationTestWidgetsFlutterBinding binding;
  final WidgetTester tester;

  final List<WidgetFrameScenarioResult> _results = [];
  final Map<String, bool> _checks = {};

  Future<WidgetFrameBenchmarkReport> run() async {
    // ignore: invalid_use_of_visible_for_testing_member
    ViewModel.reset();
    ViewModel.initialize(config: ViewModelConfig(isLoggingEnabled: false));

    try {
      for (final scenario in _scenarios) {
        await _runScenario(scenario);
      }
      return WidgetFrameBenchmarkReport(
        scenarios: List.unmodifiable(_results),
        correctnessChecks: Map.unmodifiable(_checks),
      );
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      // ignore: invalid_use_of_visible_for_testing_member
      ViewModel.reset();
    }
  }

  Future<void> _runScenario(_Scenario scenario) async {
    final instanceKey = Object();
    final buildCounter = _BuildCounter();
    final controller = _ScenarioController(instanceKey);

    await tester.pumpWidget(
      _BenchmarkApp(
        instanceKey: instanceKey,
        consumerMode: scenario.consumerMode,
        buildCounter: buildCounter,
      ),
    );
    await tester.pump();
    _verify(
      '${scenario.name}_mounts_all_consumers',
      buildCounter.value == _consumerCount,
      details: 'expected $_consumerCount, got ${buildCounter.value}',
    );

    for (var i = 0; i < _warmupFrames; i++) {
      _applyChange(controller, scenario.changeKind);
      await tester.pump();
    }
    buildCounter.reset();

    final pumpTimesUs = <double>[];
    await binding.watchPerformance(() async {
      for (var i = 0; i < _sampleFrames; i++) {
        final stopwatch = Stopwatch()..start();
        _applyChange(controller, scenario.changeKind);
        await tester.pump();
        stopwatch.stop();
        pumpTimesUs.add(
          stopwatch.elapsedTicks *
              Duration.microsecondsPerSecond /
              stopwatch.frequency,
        );
      }
    }, reportKey: scenario.performanceKey);

    final expectedBuilds = scenario.shouldRebuildConsumers
        ? _consumerCount * _sampleFrames
        : 0;
    _verify(
      '${scenario.name}_exact_consumer_builds',
      buildCounter.value == expectedBuilds,
      details: 'expected $expectedBuilds, got ${buildCounter.value}',
    );
    _verify(
      '${scenario.name}_records_every_pump',
      pumpTimesUs.length == _sampleFrames,
    );

    final managedViewModel = controller.viewModel;
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    controller.dispose();
    _verify('${scenario.name}_auto_disposes', managedViewModel.isDisposed);

    final result = WidgetFrameScenarioResult(
      name: scenario.name,
      performanceKey: scenario.performanceKey,
      consumerMode: scenario.consumerMode.name,
      changeKind: scenario.changeKind.name,
      actualConsumerBuilds: buildCounter.value,
      expectedConsumerBuilds: expectedBuilds,
      pumpTimesUs: List.unmodifiable(pumpTimesUs),
    );
    _results.add(result);
    debugPrint(
      '${scenario.name}: ${result.medianPumpMs.toStringAsFixed(3)} ms pump, '
      '${result.actualConsumerBuilds} builds',
    );
  }

  void _applyChange(_ScenarioController controller, _ChangeKind changeKind) {
    switch (changeKind) {
      case _ChangeKind.relevant:
        controller.changeRelevant();
      case _ChangeKind.irrelevant:
        controller.changeIrrelevant();
      case _ChangeKind.idle:
        break;
    }
  }

  void _verify(String name, bool condition, {String? details}) {
    _checks[name] = condition;
    if (!condition) {
      throw StateError('$name failed${details == null ? '' : ': $details'}');
    }
  }
}

double _percentile(List<double> values, double percentile) {
  final sorted = List<double>.of(values)..sort();
  final index = math.min(
    sorted.length - 1,
    ((sorted.length - 1) * percentile).round(),
  );
  return sorted[index];
}

class _BuildCounter {
  int value = 0;

  void increment() => value++;

  void reset() => value = 0;
}

class _FrameState {
  const _FrameState({required this.relevant, required this.irrelevant});

  final int relevant;
  final int irrelevant;
}

class _FrameViewModel extends StateViewModel<_FrameState> {
  _FrameViewModel()
    : super(state: const _FrameState(relevant: 0, irrelevant: 0));

  void changeRelevant() {
    setState(
      _FrameState(relevant: state.relevant + 1, irrelevant: state.irrelevant),
    );
  }

  void changeIrrelevant() {
    setState(
      _FrameState(relevant: state.relevant, irrelevant: state.irrelevant + 1),
    );
  }
}

final _frameViewModelSpec = ViewModelSpec.arg<_FrameViewModel, Object>(
  builder: (_) => _FrameViewModel(),
  key: (instanceKey) => instanceKey,
);

class _ScenarioController with ViewModelBinding {
  _ScenarioController(this.instanceKey);

  final Object instanceKey;

  _FrameViewModel get viewModel => read(_frameViewModelSpec(instanceKey));

  void changeRelevant() => viewModel.changeRelevant();

  void changeIrrelevant() => viewModel.changeIrrelevant();
}

class _BenchmarkApp extends StatelessWidget {
  const _BenchmarkApp({
    required this.instanceKey,
    required this.consumerMode,
    required this.buildCounter,
  });

  final Object instanceKey;
  final _ConsumerMode consumerMode;
  final _BuildCounter buildCounter;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 340,
            child: Wrap(
              children: List<Widget>.generate(_consumerCount, (index) {
                return switch (consumerMode) {
                  _ConsumerMode.broad => _BroadConsumer(
                    instanceKey: instanceKey,
                    index: index,
                    buildCounter: buildCounter,
                  ),
                  _ConsumerMode.selector => _SelectorConsumer(
                    instanceKey: instanceKey,
                    index: index,
                    buildCounter: buildCounter,
                  ),
                };
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _BroadConsumer extends StatefulWidget {
  const _BroadConsumer({
    required this.instanceKey,
    required this.index,
    required this.buildCounter,
  });

  final Object instanceKey;
  final int index;
  final _BuildCounter buildCounter;

  @override
  State<_BroadConsumer> createState() => _BroadConsumerState();
}

class _BroadConsumerState extends State<_BroadConsumer>
    with ViewModelStateMixin<_BroadConsumer> {
  _FrameViewModel get viewModel =>
      viewModelBinding.watch(_frameViewModelSpec(widget.instanceKey));

  @override
  Widget build(BuildContext context) {
    widget.buildCounter.increment();
    return _WorkloadTile(index: widget.index, value: viewModel.state.relevant);
  }
}

class _SelectorConsumer extends StatefulWidget {
  const _SelectorConsumer({
    required this.instanceKey,
    required this.index,
    required this.buildCounter,
  });

  final Object instanceKey;
  final int index;
  final _BuildCounter buildCounter;

  @override
  State<_SelectorConsumer> createState() => _SelectorConsumerState();
}

class _SelectorConsumerState extends State<_SelectorConsumer>
    with ViewModelStateMixin<_SelectorConsumer> {
  _FrameViewModel get viewModel =>
      viewModelBinding.read(_frameViewModelSpec(widget.instanceKey));

  @override
  Widget build(BuildContext context) {
    return StateViewModelSelector<_FrameState, int>(
      viewModel: viewModel,
      selector: (state) => state.relevant,
      builder: (context, value) {
        widget.buildCounter.increment();
        return _WorkloadTile(index: widget.index, value: value);
      },
    );
  }
}

class _WorkloadTile extends StatelessWidget {
  const _WorkloadTile({required this.index, required this.value});

  final int index;
  final int value;

  @override
  Widget build(BuildContext context) {
    final red = 40 + (value * 17 + index * 29) % 180;
    final green = 40 + (value * 11 + index * 19) % 180;
    final blue = 40 + (value * 7 + index * 13) % 180;
    return Container(
      width: 30,
      height: 30,
      margin: const EdgeInsets.all(2),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Color.fromARGB(255, red, green, blue),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '${(value + index) % 100}',
        style: const TextStyle(fontSize: 10, color: Colors.white),
      ),
    );
  }
}
