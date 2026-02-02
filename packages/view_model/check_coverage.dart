import 'dart:io';

/// Main entry for unified coverage tool.
///
/// Combines features of previous scripts:
/// - Summary table for target files with uncovered lines
/// - Per-file percentage for `view_model_binding.dart` and `view_model.dart`
/// - Missed line listing for the same files
void main() {
  final coverageFile = File('coverage/lcov.info');
  if (!coverageFile.existsSync()) {
    print('lcov.info not found');
    exit(1);
  }

  final tool = CoverageTool();
  final files = tool.parseLcov(coverageFile);

  tool.printSummaryTable(
    files,
    const [
      'view_model_spec.dart',
      'app_lifecycle_observer.dart',
      'state_store.dart',
      'view_model_binding.dart',
      'view_model.dart',
    ],
  );

  tool.printPerFilePercentages(
    files,
    const ['view_model_binding.dart', 'view_model.dart'],
  );

  tool.printMissedLinesFor(
    files,
    const ['view_model_binding.dart', 'view_model.dart'],
  );

  // Print overall coverage summary.
  tool.printOverallCoverage(files);
}

/// Coverage tool that parses lcov and prints reports.
class CoverageTool {
  /// Parses `lcov.info` to a file map.
  ///
  /// Returns map: file path -> coverage data.
  Map<String, FileCoverage> parseLcov(File file) {
    final files = <String, FileCoverage>{};
    String? currentFile;

    final lines = file.readAsLinesSync();

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('SF:')) {
        currentFile = trimmed.substring(3);
        files[currentFile] = FileCoverage();
      } else if (trimmed.startsWith('DA:')) {
        if (currentFile != null) {
          final parts = trimmed.substring(3).split(',');
          final lineNum = int.parse(parts[0]);
          final count = int.parse(parts[1]);

          files[currentFile]!.lines[lineNum] = count;
          files[currentFile]!.total++;
          if (count > 0) {
            files[currentFile]!.covered++;
          }
        }
      }
    }
    return files;
  }

  /// Prints a table of target files with coverage and missed lines.
  ///
  /// The table shows percentage and up to 20 missed lines.
  void printSummaryTable(
    Map<String, FileCoverage> files,
    List<String> targets,
  ) {
    stdout.writeln(
      '${'File'.padRight(60)} | ${'Coverage'.padRight(10)} | Missed',
    );
    stdout.writeln('-' * 100);

    for (final entry in files.entries) {
      final filePath = entry.key;
      final data = entry.value;
      final total = data.total;
      final covered = data.covered;
      final percentage = total > 0 ? (covered / total * 100) : 0.0;
      final isTarget = targets.any((t) => filePath.contains(t));
      if (!isTarget && percentage == 100.0) continue;

      final missed = data.lines.entries
          .where((e) => e.value == 0)
          .map((e) => e.key)
          .toList()
        ..sort();
      String missedStr = missed.take(20).join(', ');
      if (missed.length > 20) missedStr += '...';

      var displayPath = filePath;
      if (displayPath.length > 60) {
        displayPath = displayPath.substring(displayPath.length - 60);
      }
      stdout.writeln(
        '${displayPath.padRight(60)} | '
        '${percentage.toStringAsFixed(2).padLeft(6)}%   | '
        '$missedStr',
      );
    }
  }

  /// Prints per-file percentage for selected filenames.
  ///
  /// Matches files by `contains` on the provided names.
  void printPerFilePercentages(
    Map<String, FileCoverage> files,
    List<String> names,
  ) {
    for (final entry in files.entries) {
      final path = entry.key;
      if (!names.any((n) => path.contains(n))) continue;
      final stats = entry.value;
      final total = stats.total;
      final hit = stats.covered;
      final pct = total == 0 ? 0.0 : (hit / total * 100);
      stdout.writeln('$path: ${pct.toStringAsFixed(2)}% ($hit/$total)');
    }
  }

  /// Prints missed line numbers for selected filenames.
  ///
  /// Only files whose path contains names will be printed.
  void printMissedLinesFor(
    Map<String, FileCoverage> files,
    List<String> names,
  ) {
    for (final entry in files.entries) {
      final path = entry.key;
      if (!names.any((n) => path.contains(n))) continue;
      final missed = entry.value.lines.entries
          .where((e) => e.value == 0)
          .map((e) => e.key)
          .toList()
        ..sort();
      stdout.writeln('$path missed lines: $missed');
    }
  }

  /// Prints overall coverage across all files.
  ///
  /// Aggregates total and covered line counts to show a single
  /// percentage for the whole report.
  void printOverallCoverage(Map<String, FileCoverage> files) {
    int total = 0;
    int hit = 0;
    for (final entry in files.values) {
      total += entry.total;
      hit += entry.covered;
    }
    final pct = total == 0 ? 0.0 : (hit / total * 100);
    stdout
        .writeln('Overall coverage: ${pct.toStringAsFixed(2)}% ($hit/$total)');
  }
}

/// Coverage data holder for a single file.
class FileCoverage {
  final Map<int, int> lines = {};
  int total = 0;
  int covered = 0;
}
