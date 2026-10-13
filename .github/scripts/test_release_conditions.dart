// Run with the selected Flutter SDK's flutter_tools package configuration.
// Keep the regular test runner and coverage collector, but disable assertions
// in the test engine. This exercises release conditions on the JIT test host.
import 'dart:io';

import 'package:flutter_tools/executable.dart' as flutter;
import 'package:flutter_tools/src/base/context.dart';
import 'package:process/process.dart';

class _ReleaseTestProcessManager extends LocalProcessManager {
  @override
  Future<Process> start(
    List<Object> command, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool includeParentEnvironment = true,
    bool runInShell = false,
    ProcessStartMode mode = ProcessStartMode.normal,
  }) {
    final executable = File(command.first.toString()).uri.pathSegments.last;
    if (executable == 'flutter_tester' || executable == 'flutter_tester.exe') {
      command = [command.first, '--disable-dart-asserts', ...command.skip(1)];
    }
    return super.start(
      command,
      workingDirectory: workingDirectory,
      environment: environment,
      includeParentEnvironment: includeParentEnvironment,
      runInShell: runInShell,
      mode: mode,
    );
  }
}

Future<void> main(List<String> arguments) async {
  if (!Platform.environment.containsKey('FLUTTER_ROOT')) {
    throw StateError('Set FLUTTER_ROOT to the selected Flutter SDK.');
  }
  await context.run<void>(
    body: () => flutter.main(arguments),
    overrides: {ProcessManager: () => _ReleaseTestProcessManager()},
  );
}
