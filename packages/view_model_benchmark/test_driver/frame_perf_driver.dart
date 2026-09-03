import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

Future<void> main() {
  return integrationDriver(
    responseDataCallback: _writeAndPrintReport,
    writeResponseOnFailure: true,
  );
}

Future<void> _writeAndPrintReport(Map<String, dynamic>? data) async {
  await writeResponseData(
    data,
    testOutputFilename: 'iphone7_frame_latest',
    destinationDirectory: 'results',
  );

  final report = data?['widgetFrameBenchmark'];
  if (report is! Map<String, dynamic>) return;
  final scenarios = report['scenarios'];
  if (scenarios is! List<dynamic>) return;

  stdout
    ..writeln('\nview_model widget/frame benchmark (ms)')
    ..writeln(
      'scenario'.padRight(28) +
          'pump p50'.padLeft(10) +
          'pump p90'.padLeft(10) +
          'build avg'.padLeft(12) +
          'build p90'.padLeft(12) +
          'raster avg'.padLeft(13) +
          'missed'.padLeft(9) +
          'builds/f'.padLeft(11),
    )
    ..writeln(
      '-----------------------------------------------------------------------------------------',
    );

  for (final value in scenarios) {
    if (value is! Map<String, dynamic>) continue;
    final name = value['name'];
    final performanceKey = value['performanceKey'];
    final pumpMedian = value['medianPumpTimeMs'];
    final pumpP90 = value['p90PumpTimeMs'];
    final buildsPerFrame = value['buildsPerSampleFrame'];
    final performance = data?[performanceKey];
    if (name is! String ||
        pumpMedian is! num ||
        pumpP90 is! num ||
        buildsPerFrame is! num ||
        performance is! Map<String, dynamic>) {
      continue;
    }
    final buildAverage = performance['average_frame_build_time_millis'];
    final buildP90 = performance['90th_percentile_frame_build_time_millis'];
    final rasterAverage = performance['average_frame_rasterizer_time_millis'];
    final missedBuilds = performance['missed_frame_build_budget_count'];
    if (buildAverage is! num ||
        buildP90 is! num ||
        rasterAverage is! num ||
        missedBuilds is! num) {
      continue;
    }
    stdout.writeln(
      name.padRight(28) +
          pumpMedian.toStringAsFixed(3).padLeft(10) +
          pumpP90.toStringAsFixed(3).padLeft(10) +
          buildAverage.toStringAsFixed(3).padLeft(12) +
          buildP90.toStringAsFixed(3).padLeft(12) +
          rasterAverage.toStringAsFixed(3).padLeft(13) +
          missedBuilds.toInt().toString().padLeft(9) +
          buildsPerFrame.toStringAsFixed(0).padLeft(11),
    );
  }

  final checks = report['correctnessChecks'];
  final passed = checks is Map<String, dynamic>
      ? checks.values.where((value) => value == true).length
      : 0;
  stdout
    ..writeln(
      '-----------------------------------------------------------------------------------------',
    )
    ..writeln('correctness: $passed/${checks is Map ? checks.length : 0}');
}
