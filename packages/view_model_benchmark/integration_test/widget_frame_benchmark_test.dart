import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/widget_frame_benchmark.dart';

void main() {
  final integrationBinding =
      IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('view_model widget/frame benchmark', (tester) async {
    final report = await WidgetFrameBenchmark(
      binding: integrationBinding,
      tester: tester,
    ).run();

    integrationBinding.reportData ??= <String, dynamic>{};
    integrationBinding.reportData!['widgetFrameBenchmark'] = report.toJson();
    debugPrint(
      'widget/frame correctness: '
      '${report.correctnessChecks.length}/${report.correctnessChecks.length}',
    );

    expect(report.scenarios, hasLength(5));
    expect(report.correctnessChecks.values, everyElement(isTrue));
  });
}
