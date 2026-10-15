import 'dart:io';

import 'package:test/test.dart';

void main() {
  test(
    'native analyzer loads warnings and honors per-rule configuration',
    () async {
      final root = Directory.systemTemp.createTempSync('view_model_lint_');
      addTearDown(() => root.deleteSync(recursive: true));
      void write(String path, String content) {
        final file = File('${root.path}/$path');
        file.parent.createSync(recursive: true);
        file.writeAsStringSync(content);
      }

      write('framework/pubspec.yaml', '''
name: view_model
environment:
  sdk: '>=3.10.0 <4.0.0'
''');
      write('framework/lib/view_model.dart', '''
mixin ViewModel {
  ViewModelBinding get viewModelBinding => ViewModelBinding();
}
class ViewModelBinding {
  T read<T extends ViewModel>(ViewModelSpec<T> spec) => spec.builder();
}
class ViewModelSpec<T extends ViewModel> {
  final T Function() builder;
  ViewModelSpec({required this.builder, Object? key, bool aliveForever = false});
  static Object arg<T extends ViewModel, A>({required T Function(A) builder,
    Object? Function(A)? key}) => Object();
}
''');
      write('app/pubspec.yaml', '''
name: lint_consumer
environment:
  sdk: '>=3.10.0 <4.0.0'
dependencies:
  view_model:
    path: ../framework
''');
      write('app/lib/main.dart', '''
import 'package:view_model/view_model.dart';
class A with ViewModel {
  A get self => viewModelBinding.read(spec);
}
final spec = ViewModelSpec(builder: A.new, aliveForever: true);
final args = ViewModelSpec.arg<A, int>(builder: (_) => A());
final direct = A();
final cached = ViewModelBinding().read(spec);
''');
      final pluginPath = Directory.current.absolute.path;
      final options =
          '''
plugins:
  view_model_lint:
    path: '$pluginPath'
''';
      write('app/analysis_options.yaml', options);
      Future<ProcessResult> dart(List<String> arguments) => Process.run(
        Platform.resolvedExecutable,
        arguments,
        workingDirectory: '${root.path}/app',
      );
      final get = await dart(['pub', 'get']);
      expect(get.exitCode, 0, reason: '${get.stdout}\n${get.stderr}');
      final enabled = await dart(['analyze', '--format=machine']);
      final output = '${enabled.stdout}\n${enabled.stderr}';
      const codes = [
        'view_model_dependency_cycle',
        'view_model_cached_instance',
        'view_model_alive_forever_key',
        'view_model_unmanaged_construction',
        'view_model_parameterized_spec_key',
      ];
      expect(enabled.exitCode, isNot(0), reason: output);
      expect(output, contains('WARNING|'));
      for (final code in codes) {
        expect(output.toLowerCase(), contains(code), reason: output);
      }
      final source = File('${root.path}/app/lib/main.dart').readAsStringSync();
      write(
        'app/lib/main.dart',
        '// ignore_for_file: ${codes.map((c) => 'view_model_lint/$c').join(', ')}\n'
            '$source',
      );
      final ignored = await dart(['analyze', '--format=machine']);
      expect(
        ignored.exitCode,
        0,
        reason: '${ignored.stdout}\n${ignored.stderr}',
      );
      write('app/lib/main.dart', source);
      write(
        'app/analysis_options.yaml',
        '$options    diagnostics:\n'
            '${codes.map((code) => '      $code: false\n').join()}',
      );
      final disabled = await dart(['analyze', '--format=machine']);
      expect(
        disabled.exitCode,
        0,
        reason: '${disabled.stdout}\n${disabled.stderr}',
      );
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
