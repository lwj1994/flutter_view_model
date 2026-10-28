import 'dart:convert';
import 'dart:io';

import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/session.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';

import 'rules.dart';

/// A diagnostic reported by `dart analyze`.
class ReportedDiagnostic {
  final String code;
  final String path;
  final int offset;
  final int length;

  const ReportedDiagnostic(this.code, this.path, this.offset, this.length);
}

/// One fix that was applied, or would be applied in a dry run.
class AppliedFix {
  final String path;
  final int line;
  final String code;
  final String title;

  const AppliedFix(this.path, this.line, this.code, this.title);
}

class FixSummary {
  final List<AppliedFix> fixes;

  /// view_model_lint diagnostics left after fixing; they need a person.
  final List<ReportedDiagnostic> remaining;

  const FixSummary(this.fixes, this.remaining);
}

typedef DiagnosticSource =
    Future<List<ReportedDiagnostic>> Function(String root);

/// Runs `dart analyze --format=json` with the running SDK, so the package's
/// own plugin configuration, disabled rules, and ignore comments apply.
Future<List<ReportedDiagnostic>> analyzeWithDart(String root) async {
  final result = await Process.run(Platform.resolvedExecutable, [
    'analyze',
    '--format=json',
    root,
  ], workingDirectory: root);
  final output = result.stdout as String;
  final start = output.indexOf('{');
  if (start < 0) {
    throw StateError(
      'dart analyze produced no JSON (exit ${result.exitCode}): '
      '${result.stderr}',
    );
  }
  final json = jsonDecode(output.substring(start)) as Map<String, Object?>;
  return [
    for (final diagnostic in json['diagnostics'] as List<Object?>)
      if (diagnostic case {
        'code': final String code,
        'location': {
          'file': final String path,
          'range': {
            'start': {'offset': final int start},
            'end': {'offset': final int end},
          },
        },
      })
        ReportedDiagnostic(code.toLowerCase(), path, start, end - start),
  ];
}

/// Applies every view_model_lint quick fix in [root], round by round.
///
/// Fixes are computed from one analysis of the package. Edits that would
/// touch the same text, or insert at the same position, are deferred to the
/// next round so each fix sees the code the previous ones produced.
Future<FixSummary> fixAll(
  String root, {
  bool apply = true,
  int maxRounds = 10,
  DiagnosticSource analyze = analyzeWithDart,
  void Function(AppliedFix fix)? onFix,
}) async {
  final kinds = {
    for (final kind in viewModelFixes.keys) viewModelCodeName(kind): kind,
  };
  final fixes = <AppliedFix>[];
  var diagnostics = await analyze(root);
  for (var round = 0; round < maxRounds; round++) {
    final fixable = diagnostics.where((d) => kinds.containsKey(d.code));
    final byFile = <String, List<ReportedDiagnostic>>{};
    for (final diagnostic in fixable) {
      byFile.putIfAbsent(diagnostic.path, () => []).add(diagnostic);
    }
    if (byFile.isEmpty) break;
    final collection = AnalysisContextCollection(includedPaths: [root]);
    var changed = false;
    for (final MapEntry(key: path, value: found) in byFile.entries) {
      final AnalysisSession session;
      try {
        session = collection.contextFor(path).currentSession;
      } on StateError {
        continue; // Reported outside the analyzed package.
      }
      final unit = await session.getResolvedUnit(path);
      if (unit is! ResolvedUnitResult) continue;
      final library = await session.getResolvedLibraryByElement(
        unit.libraryElement,
      );
      if (library is! ResolvedLibraryResult) continue;
      found.sort((a, b) => a.offset.compareTo(b.offset));
      final accepted = <SourceEdit>[];
      for (final diagnostic in found) {
        final fix = await _computeFix(unit, library, diagnostic, kinds);
        if (fix == null || _overlaps(fix.$1, accepted)) continue;
        accepted.addAll(fix.$1);
        final line = unit.lineInfo.getLocation(diagnostic.offset).lineNumber;
        final applied = AppliedFix(path, line, diagnostic.code, fix.$2);
        fixes.add(applied);
        onFix?.call(applied);
      }
      if (accepted.isEmpty) continue;
      accepted.sort((a, b) => b.offset.compareTo(a.offset));
      if (apply) {
        File(
          path,
        ).writeAsStringSync(SourceEdit.applySequence(unit.content, accepted));
      }
      changed = true;
    }
    await collection.dispose();
    if (!apply || !changed) break;
    diagnostics = await analyze(root);
  }
  return FixSummary(fixes, [
    for (final diagnostic in diagnostics)
      if (diagnostic.code.startsWith('view_model_')) diagnostic,
  ]);
}

/// The edits and title of the first fix that applies to [diagnostic].
Future<(List<SourceEdit>, String)?> _computeFix(
  ResolvedUnitResult unit,
  ResolvedLibraryResult library,
  ReportedDiagnostic diagnostic,
  Map<String, ViewModelRuleKind> kinds,
) async {
  final context = CorrectionProducerContext.createResolved(
    libraryResult: library,
    unitResult: unit,
    selectionOffset: diagnostic.offset,
    selectionLength: diagnostic.length,
  );
  for (final generator in viewModelFixes[kinds[diagnostic.code]]!) {
    final producer = generator(context: context);
    final builder = ChangeBuilder(session: unit.session);
    await producer.compute(builder);
    final edits = builder.sourceChange.edits;
    // Fixes only edit the diagnosed file; anything else is not batch-safe.
    if (edits.length != 1 || edits.single.file != unit.path) continue;
    var title = producer.fixKind?.message ?? diagnostic.code;
    final arguments = producer.fixArguments ?? const [];
    for (var i = 0; i < arguments.length; i++) {
      title = title.replaceAll('{$i}', arguments[i]);
    }
    return (edits.single.edits, title);
  }
  return null;
}

bool _overlaps(List<SourceEdit> edits, List<SourceEdit> accepted) => edits.any(
  (a) => accepted.any(
    (b) =>
        a.offset == b.offset ||
        a.offset < b.offset + b.length && b.offset < a.offset + a.length,
  ),
);
