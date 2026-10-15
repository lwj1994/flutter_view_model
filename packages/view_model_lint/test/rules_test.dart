// ignore_for_file: non_constant_identifier_names

import 'package:analyzer/src/lint/registry.dart'; // ignore: implementation_imports
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:analyzer_testing/src/analysis_rule/pub_package_resolution.dart'; // ignore: implementation_imports
import 'package:test_reflective_loader/test_reflective_loader.dart';
import 'package:view_model_lint/src/rules.dart';

void main() {
  for (final kind in ViewModelRuleKind.values) {
    Registry.ruleRegistry.registerLintRule(ViewModelRule(kind));
  }
  defineReflectiveSuite(() {
    defineReflectiveTests(CachedTest);
    defineReflectiveTests(AliveTest);
    defineReflectiveTests(ConstructionTest);
    defineReflectiveTests(CycleTest);
  });
}

abstract class _ViewModelTest extends AnalysisRuleTest {
  @override
  void setUp() {
    newPackage('view_model_annotation').addFile(
      'lib/view_model_annotation.dart',
      'class GenSpec { const GenSpec(); }',
    );
    newPackage('view_model').addFile('lib/view_model.dart', '''
mixin ViewModel {
  ViewModelBinding get viewModelBinding => throw UnimplementedError();
}
class ViewModelBinding {
  T read<T extends ViewModel>(ViewModelFactory<T> spec) => spec.build();
  T watch<T extends ViewModel>(ViewModelFactory<T> spec) => spec.build();
}
abstract class ViewModelFactory<T extends ViewModel> { T build(); }
class ViewModelSpec<T extends ViewModel> extends ViewModelFactory<T> {
  ViewModelSpec({required T Function() builder, Object? key,
    Object? tag, bool aliveForever = false});
  @override
  T build() => throw UnimplementedError();
  static ViewModelSpecWithArg<T, A> arg<T extends ViewModel, A>({
    required T Function(A) builder, Object? Function(A)? key,
    bool Function(A)? aliveForever}) =>
      ViewModelSpecWithArg(builder: builder, key: key, aliveForever: aliveForever);
}
class ViewModelSpecWithArg<T extends ViewModel, A> {
  ViewModelSpecWithArg({required T Function(A) builder, Object? Function(A)? key,
    bool Function(A)? aliveForever});
}
''');
    super.setUp();
  }

  Future<void> check(String source) async {
    var content = "import 'package:view_model/view_model.dart';\n";
    final diagnostics = <ExpectedDiagnostic>[];
    while (source.contains('[[')) {
      final start = source.indexOf('[[');
      final end = source.indexOf(']]', start);
      content += source.substring(0, start);
      final marked = source.substring(start + 2, end);
      diagnostics.add(lint(content.length, marked.length));
      content += marked;
      source = source.substring(end + 2);
    }
    content += source;
    await assertDiagnostics(content, diagnostics);
  }
}

@reflectiveTest
class CachedTest extends _ViewModelTest {
  @override
  String get analysisRule => 'view_model_cached_instance';

  Future<void> test_fields_assignments_and_top_level() => check('''
class Child with ViewModel {}
final spec = ViewModelSpec(builder: Child.new);
final binding = ViewModelBinding();
final global = [[binding.read(spec)]];
class Host {
  late final child = [[binding.watch(spec)]];
  Child? other;
  Host() : other = [[binding.read(spec)]];
  void init() { other = [[binding.read(spec)]]; }
}
''');

  Future<void> test_getters_locals_callbacks_and_transformed_results() =>
      check('''
class Child with ViewModel {}
final spec = ViewModelSpec(builder: Child.new);
final binding = ViewModelBinding();
class Host {
  Child get child => binding.watch(spec);
  final callback = () => binding.read(spec);
  late final text = binding.read(spec).toString();
  Child use() { final child = binding.read(spec); return child; }
}
''');

  Future<void> test_same_method_name_is_not_framework() => check('''
class Child with ViewModel {}
class Other { Child read() => Child(); }
final child = Other().read();
''');

  Future<void> test_suppression() => check('''
class Child with ViewModel {}
final spec = ViewModelSpec(builder: Child.new);
// ignore: view_model_cached_instance
final child = ViewModelBinding().read(spec);
''');
}

@reflectiveTest
class AliveTest extends _ViewModelTest {
  @override
  String get analysisRule => 'view_model_alive_forever_key';

  Future<void> test_missing_and_null_keys() => check('''
class Child with ViewModel {}
final a = [[ViewModelSpec(builder: Child.new, aliveForever: true)]];
final b = [[ViewModelSpec(builder: Child.new, aliveForever: true, key: null)]];
final c = [[ViewModelSpec.arg<Child, int>(
  builder: (_) => Child(), aliveForever: (_) => true, key: (_) => null)]];
''');

  Future<void> test_unkeyed_parameterized_specs_are_allowed() => check('''
class Child with ViewModel {}
final a = ViewModelSpec.arg<Child, String>(builder: (_) => Child());
final b = ViewModelSpecWithArg<Child, int>(builder: (_) => Child(), key: null);
final c = ViewModelSpec.arg<Child, int>(builder: (_) => Child(), key: (_) => null);
''');

  Future<void> test_valid_and_unknown_keys() => check('''
class Child with ViewModel {}
final a = ViewModelSpec(builder: Child.new, aliveForever: true, key: 'child');
final b = ViewModelSpec(builder: Child.new);
ViewModelSpec<Child> dynamicKey(Object? key) =>
  ViewModelSpec(builder: Child.new, aliveForever: true, key: key);
final c = ViewModelSpec.arg<Child, int>(
  builder: (_) => Child(), aliveForever: (_) => true, key: (id) => id);
''');
}

@reflectiveTest
class ConstructionTest extends _ViewModelTest {
  @override
  String get analysisRule => 'view_model_unmanaged_construction';

  Future<void> test_generated_spec_factory() => check('''
import 'package:view_model_annotation/view_model_annotation.dart';
@GenSpec()
class Child with ViewModel {
  Child._();
  factory Child.spec() => Child._();
}
final spec = ViewModelSpec(builder: Child.spec);
''');

  Future<void> test_direct_and_wrong_callback() => check('''
class Child with ViewModel {}
final a = [[Child()]];
final b = ViewModelSpec(builder: Child.new, key: [[Child()]]);
final c = ViewModelSpec.arg<Child, int>(builder: ChildFactory.build,
  key: (_) => [[Child()]]);
class ChildFactory {
  static Child build(int value) => [[Child()]];
}
''');

  Future<void> test_managed_builders_factories_and_other_types() => check('''
class Child with ViewModel {}
final a = ViewModelSpec(builder: () => Child());
final b = ViewModelSpec.arg<Child, int>(builder: (_) { return Child(); });
class Factory extends ViewModelFactory<Child> {
  @override
  Child build() => Child();
}
final data = Object();
''');

  Future<void> test_inherited_view_model() => check('''
class Base with ViewModel {}
class Child extends Base {}
Child make() => [[Child()]];
''');
}

@reflectiveTest
class CycleTest extends _ViewModelTest {
  @override
  String get analysisRule => 'view_model_dependency_cycle';

  Future<void> test_shadowed_binding_is_not_parent_binding() => check('''
final spec = ViewModelSpec(builder: A.new);
class A with ViewModel {
  A use(ViewModelBinding viewModelBinding) => viewModelBinding.read(spec);
}
''');

  Future<void> test_cycle_and_self_cycle() => check('''
final aSpec = ViewModelSpec(builder: A.new);
final bSpec = ViewModelSpec(builder: B.new);
class A with ViewModel {
  B get child => [[viewModelBinding.read(bSpec)]];
  A get self => [[viewModelBinding.read(aSpec)]];
}
class B with ViewModel {
  A get child => [[viewModelBinding.watch(aSpec)]];
}
''');

  Future<void> test_diamond_is_not_cycle() => check('''
final bSpec = ViewModelSpec(builder: B.new);
final cSpec = ViewModelSpec(builder: C.new);
final dSpec = ViewModelSpec(builder: D.new);
class A with ViewModel {
  B get b => viewModelBinding.read(bSpec);
  C get c => viewModelBinding.watch(cSpec);
}
class B with ViewModel { D get d => viewModelBinding.read(dSpec); }
class C with ViewModel { D get d => viewModelBinding.read(dSpec); }
class D with ViewModel {}
''');

  Future<void> test_cross_library_getters() async {
    newFile('$testPackageLibPath/other.dart', '''
import 'package:view_model/view_model.dart';
import 'test.dart';
final bSpec = ViewModelSpec(builder: B.new);
class B with ViewModel { A get a => viewModelBinding.read(aSpec); }
''');
    await check('''
import 'other.dart';
final aSpec = ViewModelSpec(builder: A.new);
class A with ViewModel { B get b => [[viewModelBinding.watch(bSpec)]]; }
''');
  }

  Future<void> test_cross_library_overridden_binding_is_not_parent() async {
    newFile('$testPackageLibPath/other.dart', '''
import 'package:view_model/view_model.dart';
import 'test.dart';
final bSpec = ViewModelSpec(builder: B.new);
class B with ViewModel {
  @override
  ViewModelBinding get viewModelBinding => ViewModelBinding();
  A get a => viewModelBinding.read(aSpec);
}
''');
    await check('''
import 'other.dart';
final aSpec = ViewModelSpec(builder: A.new);
class A with ViewModel { B get b => viewModelBinding.watch(bSpec); }
''');
  }
}
