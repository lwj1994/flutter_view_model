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
    testOutputFilename: 'iphone7_latest',
    destinationDirectory: 'results',
  );

  final report = data?['view_modelRuntime'];
  if (report is! Map<String, dynamic>) return;
  final measurements = report['measurements'];
  if (measurements is! List<dynamic>) return;

  stdout
    ..writeln('\nview_model runtime benchmark (median ns/op)')
    ..writeln('--------------------------------------------------------');
  for (final value in measurements) {
    if (value is! Map<String, dynamic>) continue;
    final name = value['name'];
    final median = value['median'];
    final p95 = value['p95'];
    if (name is String && median is num && p95 is num) {
      stdout.writeln(
        '${name.padRight(34)} '
        '${median.toStringAsFixed(1).padLeft(11)} '
        '(p95 ${p95.toStringAsFixed(1)})',
      );
    }
  }

  final checks = report['correctnessChecks'];
  final passed = checks is Map<String, dynamic>
      ? checks.values.where((value) => value == true).length
      : 0;
  stdout
    ..writeln('--------------------------------------------------------')
    ..writeln('correctness: $passed/${checks is Map ? checks.length : 0}');
}
