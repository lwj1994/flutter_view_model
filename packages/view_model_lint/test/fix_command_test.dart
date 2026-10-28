import 'dart:io';

import 'package:test/test.dart';

const _framework = '''
mixin ViewModel {
  ViewModelBinding get viewModelBinding => ViewModelBinding();
}
class ViewModelBinding {
  T read<T extends ViewModel>(ViewModelSpec<T> spec) => spec.builder();
  T watch<T extends ViewModel>(ViewModelSpec<T> spec) => spec.builder();
  void dispose() {}
}
mixin ViewModelStateMixin {
  final ViewModelBinding viewModelBinding = ViewModelBinding();
}
abstract class StateViewModel<S> with ViewModel {}
class StateViewModelValueWatcher<S> {
  StateViewModelValueWatcher({required StateViewModel<S> viewModel});
}
class ViewModelSpec<T extends ViewModel> {
  final T Function() builder;
  ViewModelSpec({required this.builder, Object? key, bool aliveForever = false});
}
''';

const _before = '''
import 'package:view_model/view_model.dart';

class A with ViewModel {}

class B with ViewModel {}

class S extends StateViewModel<int> {}

final binding = ViewModelBinding();
final authSpec = ViewModelSpec(
  builder: A.new,
  aliveForever: true,
);
final stateSpec = ViewModelSpec(builder: S.new);
final cached = binding.read(authSpec);

class Page with ViewModelStateMixin {
  A get first => viewModelBinding.read(ViewModelSpec(builder: A.new));
  B get second => viewModelBinding.read(ViewModelSpec(builder: B.new));
  Object get watcher =>
      StateViewModelValueWatcher(viewModel: viewModelBinding.watch(stateSpec));
  late Object later;
  void init() {
    later = binding.read(stateSpec);
  }
}
''';

// Both extractions insert after `Page`, so the second waits for round two.
const _after = '''
import 'package:view_model/view_model.dart';

class A with ViewModel {}

class B with ViewModel {}

class S extends StateViewModel<int> {}

final binding = ViewModelBinding();
final authSpec = ViewModelSpec(
  builder: A.new,
  key: 'auth',
  aliveForever: true,
);
final stateSpec = ViewModelSpec(builder: S.new);
A get cached => binding.read(authSpec);

class Page with ViewModelStateMixin {
  A get first => viewModelBinding.read(_aSpec);
  B get second => viewModelBinding.read(_bSpec);
  Object get watcher =>
      StateViewModelValueWatcher(viewModel: viewModelBinding.read(stateSpec));
  late Object later;
  void init() {
    later = binding.read(stateSpec);
  }
}

final _bSpec = ViewModelSpec(builder: B.new);

final _aSpec = ViewModelSpec(builder: A.new);
''';

void main() {
  test(
    'fix command applies quick fixes in rounds and leaves the rest',
    () async {
      final root = Directory.systemTemp.createTempSync('view_model_lint_fix_');
      addTearDown(() => root.deleteSync(recursive: true));
      void write(String path, String content) {
        final file = File('${root.path}/$path');
        file.parent.createSync(recursive: true);
        file.writeAsStringSync(content);
      }

      final pluginPath = Directory.current.absolute.path;
      write('framework/pubspec.yaml', '''
name: view_model
environment:
  sdk: '>=3.10.0 <4.0.0'
''');
      write('framework/lib/view_model.dart', _framework);
      write('app/pubspec.yaml', '''
name: fix_consumer
environment:
  sdk: '>=3.10.0 <4.0.0'
dependencies:
  view_model:
    path: ../framework
''');
      write('app/analysis_options.yaml', '''
plugins:
  view_model_lint:
    path: '$pluginPath'
''');
      write('app/lib/main.dart', _before);
      final app = '${root.path}/app';
      Future<ProcessResult> dart(List<String> arguments) => Process.run(
        Platform.resolvedExecutable,
        arguments,
        workingDirectory: pluginPath,
      );
      String output(ProcessResult result) =>
          '${result.stdout}\n${result.stderr}';

      final get = await Process.run(Platform.resolvedExecutable, [
        'pub',
        'get',
      ], workingDirectory: app);
      expect(get.exitCode, 0, reason: output(get));

      final dryRun = await dart(['run', 'bin/fix.dart', '--dry-run', app]);
      expect(dryRun.exitCode, 0, reason: output(dryRun));
      expect(
        dryRun.stdout,
        contains('4 fixes available in 1 files.'),
        reason: output(dryRun),
      );
      expect(File('$app/lib/main.dart').readAsStringSync(), _before);

      final run = await dart(['run', 'bin/fix.dart', app]);
      expect(run.exitCode, 0, reason: output(run));
      expect(
        run.stdout,
        allOf(
          contains('lib/main.dart:10  view_model_alive_forever_key'),
          contains("Move the spec to the top-level variable '_bSpec'"),
          contains('5 fixes applied in 1 files.'),
          contains('2 view_model_lint diagnostics need a manual change'),
        ),
        reason: output(run),
      );
      expect(File('$app/lib/main.dart').readAsStringSync(), _after);

      final analyzed = await Process.run(Platform.resolvedExecutable, [
        'analyze',
        '--format=machine',
      ], workingDirectory: app);
      final codes = {
        for (final line in '${analyzed.stdout}'.split('\n'))
          if (line.split('|') case [_, _, final code, ...]) code.toLowerCase(),
      };
      expect(codes, {
        'view_model_cached_instance',
        'view_model_undisposed_binding',
      }, reason: output(analyzed));

      final usage = await dart(['run', 'bin/fix.dart', '--bad']);
      expect(usage.exitCode, 64);
    },
    timeout: const Timeout(Duration(minutes: 6)),
  );
}
