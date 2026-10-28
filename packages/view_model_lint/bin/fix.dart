import 'dart:io';

import 'package:view_model_lint/fix.dart';

const _usage = '''
Applies view_model_lint quick fixes to a Dart or Flutter package.

Usage: dart pub global run view_model_lint:fix [--dry-run] [<package directory>]

  --dry-run   List the fixes without changing files.
  -h, --help  Show this help.

The package must enable the view_model_lint plugin in analysis_options.yaml
and have run `pub get`. Diagnostics come from `dart analyze`, so disabled
rules and ignore comments are respected.''';

Future<void> main(List<String> arguments) async {
  final flags = arguments.where((a) => a.startsWith('-')).toSet();
  final paths = arguments.where((a) => !a.startsWith('-')).toList();
  if (flags.contains('-h') || flags.contains('--help')) {
    stdout.writeln(_usage);
    return;
  }
  if (paths.length > 1 || flags.difference({'--dry-run'}).isNotEmpty) {
    stderr.writeln(_usage);
    exitCode = 64;
    return;
  }
  final directory = Directory(paths.isEmpty ? '.' : paths.single);
  if (!File('${directory.path}/pubspec.yaml').existsSync()) {
    stderr.writeln('No pubspec.yaml in ${directory.absolute.path}.');
    exitCode = 66;
    return;
  }
  final root = directory.resolveSymbolicLinksSync();
  final dryRun = flags.contains('--dry-run');
  String relative(String path) =>
      path.startsWith('$root/') ? path.substring(root.length + 1) : path;
  final FixSummary summary;
  try {
    summary = await fixAll(
      root,
      apply: !dryRun,
      onFix: (fix) => stdout.writeln(
        '${relative(fix.path)}:${fix.line}  ${fix.code}  ${fix.title}',
      ),
    );
  } on StateError catch (error) {
    stderr.writeln(error.message);
    exitCode = 1;
    return;
  }
  final files = summary.fixes.map((fix) => fix.path).toSet().length;
  stdout.writeln(
    dryRun
        ? '${summary.fixes.length} fixes available in $files files.'
        : '${summary.fixes.length} fixes applied in $files files.',
  );
  if (!dryRun && summary.remaining.isNotEmpty) {
    stdout.writeln(
      '${summary.remaining.length} view_model_lint diagnostics need a manual '
      'change; run dart analyze to see them.',
    );
  }
}
