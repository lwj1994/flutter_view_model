import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:view_model_benchmark/benchmark_suite.dart';

void main() {
  final integrationBinding =
      IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('view_model runtime benchmark', (tester) async {
    final report = await ViewModelBenchmarkSuite().run(
      flushAsyncEvents: tester.pump,
    );

    integrationBinding.reportData = <String, Object?>{
      'view_modelRuntime': report.toJson(),
    };
    debugPrint(report.formatSummary());

    expect(report.measurements, isNotEmpty);
    expect(report.correctnessChecks.values, everyElement(isTrue));
  });
}
