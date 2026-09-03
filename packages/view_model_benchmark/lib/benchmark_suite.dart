import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:view_model/view_model.dart';

const int _warmupRounds = 4;
const int _sampleRounds = 15;
const int _totalRounds = _warmupRounds + _sampleRounds;

int _blackHole = 0;

void _consume(Object? value) {
  _blackHole ^= identityHashCode(value);
}

class BenchmarkMeasurement {
  BenchmarkMeasurement({
    required this.name,
    required this.operation,
    required this.iterationsPerRound,
    required this.parameters,
    required this.samplesNsPerOperation,
  });

  final String name;
  final String operation;
  final int iterationsPerRound;
  final Map<String, Object?> parameters;
  final List<double> samplesNsPerOperation;

  double get meanNs =>
      samplesNsPerOperation.reduce((a, b) => a + b) /
      samplesNsPerOperation.length;

  double get medianNs => _percentile(0.50);

  double get p95Ns => _percentile(0.95);

  double get standardDeviationNs {
    final mean = meanNs;
    final variance =
        samplesNsPerOperation
            .map((sample) => math.pow(sample - mean, 2).toDouble())
            .reduce((a, b) => a + b) /
        samplesNsPerOperation.length;
    return math.sqrt(variance);
  }

  double _percentile(double percentile) {
    final sorted = List<double>.of(samplesNsPerOperation)..sort();
    final index = ((sorted.length - 1) * percentile).round();
    return sorted[index];
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'name': name,
    'operation': operation,
    'iterationsPerRound': iterationsPerRound,
    'parameters': parameters,
    'unit': 'ns/op',
    'mean': meanNs,
    'median': medianNs,
    'p95': p95Ns,
    'standardDeviation': standardDeviationNs,
    'samples': samplesNsPerOperation,
  };
}

class BenchmarkReport {
  BenchmarkReport({
    required this.measurements,
    required this.correctnessChecks,
  });

  final List<BenchmarkMeasurement> measurements;
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
      'flutterChannel': FlutterVersion.channel,
      'flutterRevision': FlutterVersion.frameworkRevision,
      'dartVersion': FlutterVersion.dartVersion ?? Platform.version,
      'stopwatchFrequency': Stopwatch().frequency,
      'warmupRounds': _warmupRounds,
      'sampleRounds': _sampleRounds,
      'antiOptimizationToken': _blackHole,
    },
    'correctnessChecks': correctnessChecks,
    'measurements': measurements.map((value) => value.toJson()).toList(),
  };

  String formatSummary() {
    final buffer = StringBuffer()
      ..writeln('\nview_model runtime benchmark')
      ..writeln('unit: ns/op, median of $_sampleRounds samples')
      ..writeln('------------------------------------------------------------');
    for (final measurement in measurements) {
      buffer.writeln(
        '${measurement.name.padRight(34)} '
        '${measurement.medianNs.toStringAsFixed(1).padLeft(11)} '
        '(p95 ${measurement.p95Ns.toStringAsFixed(1)})',
      );
    }
    buffer
      ..writeln('------------------------------------------------------------')
      ..writeln(
        'correctness: ${correctnessChecks.length}/${correctnessChecks.length}',
      );
    return buffer.toString();
  }
}

class ViewModelBenchmarkSuite {
  final List<BenchmarkMeasurement> _measurements = [];
  final Map<String, bool> _correctnessChecks = {};

  Future<BenchmarkReport> run({
    required Future<void> Function() flushAsyncEvents,
  }) async {
    // ignore: invalid_use_of_visible_for_testing_member
    ViewModel.reset();
    ViewModel.initialize(config: ViewModelConfig(isLoggingEnabled: false));

    try {
      _benchmarkColdResolve();
      _benchmarkHotResolution();
      _benchmarkNotificationFanOut();
      _benchmarkSelectors();
      _benchmarkDependencyChains();
      _benchmarkDiamondGraph();
      _benchmarkLifecycleTree();
      await _benchmarkPauseResume(flushAsyncEvents);

      return BenchmarkReport(
        measurements: List.unmodifiable(_measurements),
        correctnessChecks: Map.unmodifiable(_correctnessChecks),
      );
    } finally {
      // ignore: invalid_use_of_visible_for_testing_member
      ViewModel.reset();
    }
  }

  void _benchmarkColdResolve() {
    final spec = ViewModelSpec<_CounterViewModel>(
      builder: _CounterViewModel.new,
    );
    _CounterViewModel? last;

    _measureSync(
      name: 'resolve_create_dispose',
      operation: 'read(spec) + binding.dispose()',
      iterations: 1000,
      body: (iterations) {
        for (var i = 0; i < iterations; i++) {
          final binding = _CountingBinding();
          last = binding.read(spec);
          binding.dispose();
          if (!last!.isDisposed) {
            throw StateError('冷启动实例没有自动释放');
          }
        }
        _consume(last);
      },
    );

    _verify('cold_resolve_auto_disposes', last?.isDisposed ?? false);
  }

  void _benchmarkHotResolution() {
    final readBinding = _CountingBinding();
    final readSpec = ViewModelSpec<_CounterViewModel>(
      builder: _CounterViewModel.new,
      key: Object(),
    );
    final expectedRead = readBinding.read(readSpec);
    _CounterViewModel? actualRead;

    _measureSync(
      name: 'hot_read_cache_hit',
      operation: 'read(spec)',
      iterations: 20000,
      body: (iterations) {
        for (var i = 0; i < iterations; i++) {
          actualRead = readBinding.read(readSpec);
        }
        _consume(actualRead);
      },
    );
    _verify('hot_read_reuses_instance', identical(expectedRead, actualRead));
    readBinding.dispose();
    _verify('hot_read_disposes_instance', expectedRead.isDisposed);

    final watchBinding = _CountingBinding();
    final watchSpec = ViewModelSpec<_CounterViewModel>(
      builder: _CounterViewModel.new,
      key: Object(),
    );
    final expectedWatch = watchBinding.watch(watchSpec);
    _CounterViewModel? actualWatch;

    _measureSync(
      name: 'hot_watch_cache_hit',
      operation: 'watch(spec)',
      iterations: 20000,
      body: (iterations) {
        for (var i = 0; i < iterations; i++) {
          actualWatch = watchBinding.watch(watchSpec);
        }
        _consume(actualWatch);
      },
    );
    _verify('hot_watch_reuses_instance', identical(expectedWatch, actualWatch));
    watchBinding.dispose();
    _verify('hot_watch_disposes_instance', expectedWatch.isDisposed);
  }

  void _benchmarkNotificationFanOut() {
    for (final entry in <(int, int)>[(1, 20000), (10, 10000), (100, 2000)]) {
      final listenerCount = entry.$1;
      final iterations = entry.$2;
      final spec = ViewModelSpec<_CounterViewModel>(
        builder: _CounterViewModel.new,
        key: Object(),
      );
      final bindings = List.generate(listenerCount, (_) => _CountingBinding());
      final viewModel = bindings.first.watch(spec);
      for (final binding in bindings.skip(1)) {
        binding.watch(spec);
      }

      _measureSync(
        name: 'notify_${listenerCount}_bindings',
        operation: 'notifyListeners()',
        iterations: iterations,
        parameters: <String, Object?>{'bindings': listenerCount},
        body: (count) {
          for (var i = 0; i < count; i++) {
            viewModel.increment();
          }
        },
      );

      final observed = bindings.fold<int>(
        0,
        (sum, binding) => sum + binding.updateCount,
      );
      _verify(
        'notify_${listenerCount}_bindings_exact_delivery',
        observed == listenerCount * iterations * _totalRounds,
        details:
            'expected '
            '${listenerCount * iterations * _totalRounds}, got $observed',
      );
      for (final binding in bindings) {
        binding.dispose();
      }
      _verify(
        'notify_${listenerCount}_bindings_auto_dispose',
        viewModel.isDisposed,
      );
    }
  }

  void _benchmarkSelectors() {
    const listenerCount = 100;
    const iterations = 2000;
    final spec = ViewModelSpec<_SelectorViewModel>(
      builder: _SelectorViewModel.new,
      key: Object(),
    );
    final bindings = List.generate(listenerCount, (_) => _CountingBinding());
    var callbackCount = 0;
    for (final binding in bindings) {
      binding.listenStateSelect<_SelectorViewModel, _SelectorState, int>(
        spec,
        selector: (state) => state.relevant,
        onChanged: (_, _) => callbackCount++,
      );
    }
    final viewModel = bindings.first.read(spec);

    _measureSync(
      name: 'selector_relevant_100',
      operation: 'setState + 100 selectors',
      iterations: iterations,
      parameters: const <String, Object?>{
        'selectors': listenerCount,
        'selectedFieldChanges': true,
      },
      body: (count) {
        for (var i = 0; i < count; i++) {
          viewModel.changeRelevant();
        }
      },
    );
    _verify(
      'selector_relevant_exact_delivery',
      callbackCount == listenerCount * iterations * _totalRounds,
      details:
          'expected ${listenerCount * iterations * _totalRounds}, '
          'got $callbackCount',
    );

    callbackCount = 0;
    _measureSync(
      name: 'selector_irrelevant_100',
      operation: 'setState + 100 selectors',
      iterations: iterations,
      parameters: const <String, Object?>{
        'selectors': listenerCount,
        'selectedFieldChanges': false,
      },
      body: (count) {
        for (var i = 0; i < count; i++) {
          viewModel.changeIrrelevant();
        }
      },
    );
    _verify('selector_irrelevant_is_filtered', callbackCount == 0);

    for (final binding in bindings) {
      binding.dispose();
    }
    _verify('selector_instance_auto_disposes', viewModel.isDisposed);
  }

  void _benchmarkDependencyChains() {
    for (final entry in <(int, int)>[
      (1, 20000),
      (4, 8000),
      (8, 4000),
      (16, 2000),
    ]) {
      final depth = entry.$1;
      final iterations = entry.$2;
      final spec = _createDependencyChainSpec(depth);
      final binding = _CountingBinding();
      var leaf = binding.watch(spec);
      while (true) {
        final child = leaf.child;
        if (child == null) break;
        leaf = child;
      }

      _measureSync(
        name: 'dependency_chain_depth_$depth',
        operation: 'leaf notify -> root binding',
        iterations: iterations,
        parameters: <String, Object?>{
          'nodes': depth,
          'dependencyEdges': depth - 1,
        },
        body: (count) {
          for (var i = 0; i < count; i++) {
            leaf.emit();
          }
        },
      );

      _verify(
        'dependency_chain_${depth}_exact_delivery',
        binding.updateCount == iterations * _totalRounds,
        details:
            'expected ${iterations * _totalRounds}, '
            'got ${binding.updateCount}',
      );
      binding.dispose();
      _verify('dependency_chain_${depth}_auto_disposes', leaf.isDisposed);
    }
  }

  void _benchmarkDiamondGraph() {
    const iterations = 5000;
    final graph = _DiamondGraph();
    final binding = _CountingBinding();
    final root = binding.watch(graph.rootSpec);
    final left = root.left;
    final right = root.right;
    final leftLeaf = left.leaf;
    final rightLeaf = right.leaf;

    _verify('diamond_leaf_is_shared', identical(leftLeaf, rightLeaf));
    _measureSync(
      name: 'diamond_graph_dedup',
      operation: 'shared leaf notify -> root binding',
      iterations: iterations,
      parameters: const <String, Object?>{
        'branches': 2,
        'uniqueDeliveryExpected': true,
      },
      body: (count) {
        for (var i = 0; i < count; i++) {
          leftLeaf.emit();
        }
      },
    );

    _verify(
      'diamond_graph_delivers_once_per_transaction',
      binding.updateCount == iterations * _totalRounds,
      details:
          'expected ${iterations * _totalRounds}, '
          'got ${binding.updateCount}',
    );
    binding.dispose();
    _verify(
      'diamond_graph_auto_disposes',
      root.isDisposed && leftLeaf.isDisposed,
    );
  }

  void _benchmarkLifecycleTree() {
    const depth = 8;
    const iterations = 300;
    final spec = _createLifecycleChainSpec(depth);
    _LifecycleNode.created = 0;
    _LifecycleNode.disposed = 0;
    _LifecycleNode? lastLeaf;

    _measureSync(
      name: 'lifecycle_tree_depth_8',
      operation: 'create tree + binding.dispose()',
      iterations: iterations,
      parameters: const <String, Object?>{'nodes': depth},
      body: (count) {
        for (var i = 0; i < count; i++) {
          final binding = _CountingBinding();
          var node = binding.read(spec);
          while (true) {
            final child = node.child;
            if (child == null) break;
            node = child;
          }
          lastLeaf = node;
          binding.dispose();
        }
        _consume(lastLeaf);
      },
    );

    final expected = depth * iterations * _totalRounds;
    _verify(
      'lifecycle_tree_creates_every_node',
      _LifecycleNode.created == expected,
      details: 'expected $expected, got ${_LifecycleNode.created}',
    );
    _verify(
      'lifecycle_tree_disposes_every_node',
      _LifecycleNode.disposed == expected && (lastLeaf?.isDisposed ?? false),
      details: 'expected $expected, got ${_LifecycleNode.disposed}',
    );
  }

  Future<void> _benchmarkPauseResume(
    Future<void> Function() flushAsyncEvents,
  ) async {
    const iterations = 20000;
    final provider = _ManualPauseProvider();
    final binding = _CountingBinding()..addPauseProvider(provider);
    final spec = ViewModelSpec<_CounterViewModel>(
      builder: _CounterViewModel.new,
      key: Object(),
    );
    final viewModel = binding.watch(spec);

    _measureSync(
      name: 'notify_active_binding',
      operation: 'notify while active',
      iterations: iterations,
      body: (count) {
        for (var i = 0; i < count; i++) {
          viewModel.increment();
        }
      },
    );
    _verify(
      'active_binding_exact_delivery',
      binding.updateCount == iterations * _totalRounds,
    );

    binding.updateCount = 0;
    provider.pause();
    await flushAsyncEvents();
    _verify('pause_provider_pauses_binding', binding.isPaused);

    _measureSync(
      name: 'notify_paused_binding',
      operation: 'notify while paused',
      iterations: iterations,
      body: (count) {
        for (var i = 0; i < count; i++) {
          viewModel.increment();
        }
      },
    );
    _verify('paused_binding_suppresses_updates', binding.updateCount == 0);

    provider.resume();
    await flushAsyncEvents();
    _verify('resume_delivers_one_catch_up', binding.updateCount == 1);
    _verify('resume_marks_binding_active', !binding.isPaused);

    binding.dispose();
    provider.dispose();
    _verify('pause_scenario_auto_disposes', viewModel.isDisposed);
  }

  void _measureSync({
    required String name,
    required String operation,
    required int iterations,
    required void Function(int iterations) body,
    Map<String, Object?> parameters = const <String, Object?>{},
  }) {
    for (var i = 0; i < _warmupRounds; i++) {
      body(iterations);
    }

    final samples = <double>[];
    for (var i = 0; i < _sampleRounds; i++) {
      final stopwatch = Stopwatch()..start();
      body(iterations);
      stopwatch.stop();
      samples.add(
        stopwatch.elapsedTicks *
            Duration.microsecondsPerSecond *
            1000 /
            stopwatch.frequency /
            iterations,
      );
    }

    final measurement = BenchmarkMeasurement(
      name: name,
      operation: operation,
      iterationsPerRound: iterations,
      parameters: parameters,
      samplesNsPerOperation: samples,
    );
    _measurements.add(measurement);
    debugPrint(
      '${measurement.name}: '
      '${measurement.medianNs.toStringAsFixed(1)} ns/op',
    );
  }

  void _verify(String name, bool condition, {String? details}) {
    _correctnessChecks[name] = condition;
    if (!condition) {
      throw StateError('$name failed${details == null ? '' : ': $details'}');
    }
  }
}

class _CountingBinding with ViewModelBinding {
  int updateCount = 0;

  @override
  void onUpdate() {
    super.onUpdate();
    updateCount++;
  }
}

class _ManualPauseProvider with ViewModelBindingPauseProvider {}

class _CounterViewModel with ViewModel {
  int value = 0;

  void increment() {
    value++;
    notifyListeners();
  }
}

class _SelectorState {
  const _SelectorState({required this.relevant, required this.irrelevant});

  final int relevant;
  final int irrelevant;
}

class _SelectorViewModel extends StateViewModel<_SelectorState> {
  _SelectorViewModel()
    : super(state: const _SelectorState(relevant: 0, irrelevant: 0));

  void changeRelevant() {
    setState(
      _SelectorState(
        relevant: state.relevant + 1,
        irrelevant: state.irrelevant,
      ),
    );
  }

  void changeIrrelevant() {
    setState(
      _SelectorState(
        relevant: state.relevant,
        irrelevant: state.irrelevant + 1,
      ),
    );
  }
}

class _DependencyNode with ViewModel {
  _DependencyNode(this._childSpec);

  final ViewModelSpec<_DependencyNode>? _childSpec;

  _DependencyNode? get child {
    final childSpec = _childSpec;
    return childSpec == null ? null : viewModelBinding.watch(childSpec);
  }

  void emit() => notifyListeners();
}

ViewModelSpec<_DependencyNode> _createDependencyChainSpec(int depth) {
  ViewModelSpec<_DependencyNode>? current;
  for (var i = 0; i < depth; i++) {
    final child = current;
    current = ViewModelSpec<_DependencyNode>(
      builder: () => _DependencyNode(child),
      key: Object(),
    );
  }
  return current!;
}

class _DiamondGraph {
  _DiamondGraph() {
    leafSpec = ViewModelSpec<_DependencyNode>(
      builder: () => _DependencyNode(null),
      key: Object(),
    );
    leftSpec = ViewModelSpec<_DiamondBranch>(
      builder: () => _DiamondBranch(leafSpec),
      key: Object(),
    );
    rightSpec = ViewModelSpec<_DiamondBranch>(
      builder: () => _DiamondBranch(leafSpec),
      key: Object(),
    );
    rootSpec = ViewModelSpec<_DiamondRoot>(
      builder: () => _DiamondRoot(leftSpec, rightSpec),
      key: Object(),
    );
  }

  late final ViewModelSpec<_DependencyNode> leafSpec;
  late final ViewModelSpec<_DiamondBranch> leftSpec;
  late final ViewModelSpec<_DiamondBranch> rightSpec;
  late final ViewModelSpec<_DiamondRoot> rootSpec;
}

class _DiamondBranch with ViewModel {
  _DiamondBranch(this._leafSpec);

  final ViewModelSpec<_DependencyNode> _leafSpec;

  _DependencyNode get leaf => viewModelBinding.watch(_leafSpec);
}

class _DiamondRoot with ViewModel {
  _DiamondRoot(this._leftSpec, this._rightSpec);

  final ViewModelSpec<_DiamondBranch> _leftSpec;
  final ViewModelSpec<_DiamondBranch> _rightSpec;

  _DiamondBranch get left => viewModelBinding.watch(_leftSpec);

  _DiamondBranch get right => viewModelBinding.watch(_rightSpec);
}

class _LifecycleNode with ViewModel {
  _LifecycleNode(this._childSpec);

  static int created = 0;
  static int disposed = 0;

  final ViewModelSpec<_LifecycleNode>? _childSpec;

  _LifecycleNode? get child {
    final childSpec = _childSpec;
    return childSpec == null ? null : viewModelBinding.read(childSpec);
  }

  @override
  void onCreate(InstanceArg arg) {
    super.onCreate(arg);
    created++;
  }

  @override
  void onDispose(InstanceArg arg) {
    super.onDispose(arg);
    disposed++;
  }
}

ViewModelSpec<_LifecycleNode> _createLifecycleChainSpec(int depth) {
  ViewModelSpec<_LifecycleNode>? current;
  for (var i = 0; i < depth; i++) {
    final child = current;
    current = ViewModelSpec<_LifecycleNode>(
      builder: () => _LifecycleNode(child),
      key: Object(),
    );
  }
  return current!;
}
