// ignore_for_file: non_constant_identifier_names

import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/src/lint/registry.dart'; // ignore: implementation_imports
import 'package:analyzer_plugin/protocol/protocol_common.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:analyzer_testing/src/analysis_rule/pub_package_resolution.dart'; // ignore: implementation_imports
import 'package:test/test.dart';
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
    defineReflectiveTests(ListenInBuildTest);
    defineReflectiveTests(InstanceHandoffTest);
    defineReflectiveTests(IdentityCollisionTest);
    defineReflectiveTests(SelectorWithWatchTest);
    defineReflectiveTests(UndisposedBindingTest);
    defineReflectiveTests(TemporarySpecTest);
    defineReflectiveTests(CachedLookupTest);
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
abstract interface class ViewModelBindingHost {}
mixin ViewModel implements ViewModelBindingHost {
  ViewModelBinding get viewModelBinding => throw UnimplementedError();
  void Function() listen({required void Function() onChanged}) => () {};
  static T readCached<T extends ViewModel>({Object? key}) =>
      throw UnimplementedError();
}
class ViewModelBinding {
  T read<T extends ViewModel>(ViewModelFactory<T> spec) => spec.build();
  T watch<T extends ViewModel>(ViewModelFactory<T> spec) => spec.build();
  T readCached<T extends ViewModel>({Object? key, Object? tag}) =>
      throw UnimplementedError();
  T? maybeWatchCached<T extends ViewModel>({Object? key, Object? tag}) => null;
  List<T> readCachesByTag<T extends ViewModel>(Object tag) => [];
  void listen<T extends ViewModel>(ViewModelFactory<T> spec,
    {required void Function() onChanged}) {}
  void onUpdate() {}
  void dispose() {}
}
extension ViewModelBindingHostExtension on ViewModelBindingHost {
  VM watchViewModel<VM extends ViewModel>(
    {required ViewModelFactory<VM> factory}) => factory.build();
  VM readViewModel<VM extends ViewModel>(
    {required ViewModelFactory<VM> factory}) => factory.build();
  void listenViewModel<VM extends ViewModel>(
    {required ViewModelFactory<VM> factory,
    required void Function() onChanged}) {}
}
mixin ViewModelStateMixin implements ViewModelBindingHost {
  late final ViewModelBinding viewModelBinding = ViewModelBinding();
}
abstract class StateViewModel<S> with ViewModel {}
class StateViewModelValueWatcher<S> {
  StateViewModelValueWatcher({required StateViewModel<S> viewModel});
}
class ViewModelBuilder<T extends ViewModel> {
  ViewModelBuilder(ViewModelFactory<T> provider);
}
abstract class ViewModelFactory<T extends ViewModel> { T build(); }
class ViewModelSpec<T extends ViewModel> extends ViewModelFactory<T> {
  ViewModelSpec({required T Function() builder, Object? key,
    Object? tag, bool aliveForever = false});
  @override
  T build() => throw UnimplementedError();
  void setProxy(ViewModelSpec<T> spec) {}
  static ViewModelSpecWithArg<T, A> arg<T extends ViewModel, A>({
    required T Function(A) builder, Object? Function(A)? key,
    bool Function(A)? aliveForever}) =>
      ViewModelSpecWithArg(builder: builder, key: key, aliveForever: aliveForever);
}
class ViewModelProvider<T extends ViewModel> extends ViewModelSpec<T> {
  ViewModelProvider({required super.builder});
}
class ViewModelSpecWithArg<T extends ViewModel, A> {
  ViewModelSpecWithArg({required T Function(A) builder, Object? Function(A)? key,
    bool Function(A)? aliveForever});
  ViewModelFactory<T> call(A arg) => throw UnimplementedError();
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

  /// Applies fix number [fix] of [kind] to the diagnostic marked in [source]
  /// and expects [expected], or no edit when [expected] is null.
  Future<void> checkFix(
    ViewModelRuleKind kind,
    String source,
    String? expected, {
    int fix = 0,
  }) async {
    const header = "import 'package:view_model/view_model.dart';\n";
    final start = source.indexOf('[[');
    final end = source.indexOf(']]');
    final content =
        header +
        source.substring(0, start) +
        source.substring(start + 2, end) +
        source.substring(end + 2);
    final offset = header.length + start;
    final length = end - start - 2;
    await assertDiagnostics(content, [lint(offset, length)]);
    final diagnostic = result.diagnostics.singleWhere(
      (d) => d.problemMessage.offset == offset,
    );
    final library =
        await result.session.getResolvedLibrary(result.path)
            as ResolvedLibraryResult;
    final context = CorrectionProducerContext.createResolved(
      libraryResult: library,
      unitResult: result,
      diagnostic: diagnostic,
      selectionOffset: offset,
      selectionLength: length,
    );
    final builder = ChangeBuilder(session: result.session);
    await viewModelFixes[kind]![fix](context: context).compute(builder);
    final edits = builder.sourceChange.edits;
    if (expected == null) {
      expect(edits, isEmpty);
      return;
    }
    expect(
      SourceEdit.applySequence(content, edits.single.edits),
      header + expected,
    );
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

  Future<void> test_block_getter_local_declarations() => check('''
class Child with ViewModel {}
final spec = ViewModelSpec(builder: Child.new);
class Host with ViewModel {
  Child get child {
    final session = viewModelBinding.read(spec);
    session.toString();
    return session;
  }
  Child get observed {
    final session = viewModelBinding.watch(spec);
    return session;
  }
}
''');

  Future<void> test_block_getter_and_method_local_assignments() => check('''
class Child with ViewModel {}
final spec = ViewModelSpec(builder: Child.new);
class Host with ViewModel {
  Child get child {
    Child session;
    session = viewModelBinding.read(spec);
    return session;
  }
  Child resolve() {
    Child session;
    session = viewModelBinding.watch(spec);
    return session;
  }
}
''');

  Future<void> test_block_getter_field_assignments() => check('''
class Child with ViewModel {}
final spec = ViewModelSpec(builder: Child.new);
class Host with ViewModel {
  late Child session;
  Child get child {
    this.session = [[viewModelBinding.read(spec)]];
    session = [[viewModelBinding.watch(spec)]];
    return session;
  }
}
''');

  Future<void> test_cached_and_extension_resolutions() => check('''
class Child with ViewModel {}
final spec = ViewModelSpec(builder: Child.new);
class Page with ViewModelStateMixin {
  late final a = [[watchViewModel(factory: spec)]];
  late final b = [[viewModelBinding.readCached<Child>(key: 'b')]];
  late final c = [[viewModelBinding.maybeWatchCached<Child>(key: 'c')]];
  late final d = viewModelBinding.readCachesByTag<Child>('d');
}
''');

  Future<void> test_fix_field_becomes_getter() => checkFix(
    ViewModelRuleKind.cachedInstance,
    '''
class Child with ViewModel {}
final spec = ViewModelSpec(builder: Child.new);
class Host with ViewModel {
  /// The child.
  late final Child child = [[viewModelBinding.read(spec)]];
}
''',
    '''
class Child with ViewModel {}
final spec = ViewModelSpec(builder: Child.new);
class Host with ViewModel {
  /// The child.
  Child get child => viewModelBinding.read(spec);
}
''',
  );

  Future<void> test_fix_inferred_top_level_and_static_fields_1() async {
    await checkFix(
      ViewModelRuleKind.cachedInstance,
      '''
class Child with ViewModel {}
final spec = ViewModelSpec(builder: Child.new);
final binding = ViewModelBinding();
final global = [[binding.watch(spec)]];
''',
      '''
class Child with ViewModel {}
final spec = ViewModelSpec(builder: Child.new);
final binding = ViewModelBinding();
Child get global => binding.watch(spec);
''',
    );
  }

  Future<void> test_fix_inferred_top_level_and_static_fields_2() async {
    await checkFix(
      ViewModelRuleKind.cachedInstance,
      '''
class Child with ViewModel {}
final spec = ViewModelSpec(builder: Child.new);
final binding = ViewModelBinding();
class Host {
  static final shared = [[binding.read(spec)]];
}
''',
      '''
class Child with ViewModel {}
final spec = ViewModelSpec(builder: Child.new);
final binding = ViewModelBinding();
class Host {
  static Child get shared => binding.read(spec);
}
''',
    );
  }

  Future<void> test_fix_skips_assignments_and_mutable_fields_1() async {
    await checkFix(ViewModelRuleKind.cachedInstance, '''
class Child with ViewModel {}
final spec = ViewModelSpec(builder: Child.new);
final binding = ViewModelBinding();
class Host {
  Child? child;
  void init() { child = [[binding.read(spec)]]; }
}
''', null);
  }

  Future<void> test_fix_skips_assignments_and_mutable_fields_2() async {
    await checkFix(ViewModelRuleKind.cachedInstance, '''
class Child with ViewModel {}
final spec = ViewModelSpec(builder: Child.new);
class Host with ViewModel {
  late Child child = [[viewModelBinding.read(spec)]];
}
''', null);
  }

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

  Future<void> test_fix_adds_key_from_variable_name_1() async {
    await checkFix(
      ViewModelRuleKind.aliveForeverKey,
      '''
class Child with ViewModel {}
final authSpec = [[ViewModelSpec(builder: Child.new, aliveForever: true)]];
''',
      '''
class Child with ViewModel {}
final authSpec = ViewModelSpec(builder: Child.new, key: 'auth', aliveForever: true);
''',
    );
  }

  Future<void> test_fix_adds_key_from_variable_name_2() async {
    await checkFix(
      ViewModelRuleKind.aliveForeverKey,
      '''
class Child with ViewModel {}
final retained = [[ViewModelSpec(builder: Child.new, aliveForever: true, key: null)]];
''',
      '''
class Child with ViewModel {}
final retained = ViewModelSpec(builder: Child.new, aliveForever: true, key: 'retained');
''',
    );
  }

  Future<void> test_fix_adds_argument_key_1() async {
    await checkFix(
      ViewModelRuleKind.aliveForeverKey,
      '''
class Child with ViewModel {}
final userCacheSpec = [[ViewModelSpec.arg<Child, int>(
  builder: (_) => Child(), aliveForever: (_) => true)]];
''',
      '''
class Child with ViewModel {}
final userCacheSpec = ViewModelSpec.arg<Child, int>(
  builder: (_) => Child(), key: (arg) => ('userCache', arg), aliveForever: (_) => true);
''',
    );
  }

  Future<void> test_fix_adds_argument_key_2() async {
    await checkFix(
      ViewModelRuleKind.aliveForeverKey,
      '''
class Child with ViewModel {}
final cache = [[ViewModelSpecWithArg<Child, int>(
  builder: (_) => Child(), aliveForever: (_) => true, key: (_) => null)]];
''',
      '''
class Child with ViewModel {}
final cache = ViewModelSpecWithArg<Child, int>(
  builder: (_) => Child(), aliveForever: (_) => true, key: (arg) => ('cache', arg));
''',
    );
  }

  Future<void> test_fix_keeps_one_argument_per_line() => checkFix(
    ViewModelRuleKind.aliveForeverKey,
    '''
class Child with ViewModel {}
final authSpec = [[ViewModelSpec(
  builder: Child.new,
  aliveForever: true,
)]];
''',
    '''
class Child with ViewModel {}
final authSpec = ViewModelSpec(
  builder: Child.new,
  key: 'auth',
  aliveForever: true,
);
''',
  );

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

@reflectiveTest
class ListenInBuildTest extends _ViewModelTest {
  @override
  String get analysisRule => 'view_model_listen_in_build';

  Future<void> test_build_getters_and_refresh() => check('''
class Child with ViewModel {}
final spec = ViewModelSpec(builder: Child.new);
class Page with ViewModelStateMixin {
  Object build(Object context) {
    [[viewModelBinding.listen(spec, onChanged: () {})]];
    [[listenViewModel(factory: spec, onChanged: () {})]];
    return Object();
  }
  void didUpdateWidget(Object old) {
    [[viewModelBinding.listen(spec, onChanged: () {})]];
  }
  Child get child {
    [[viewModelBinding.read(spec).listen(onChanged: () {})]];
    return viewModelBinding.read(spec);
  }
}
class Host extends ViewModelBinding {
  @override
  void onUpdate() {
    [[listen(spec, onChanged: () {})]];
  }
}
class Parent with ViewModel {
  Child get child {
    [[viewModelBinding.listen(spec, onChanged: () {})]];
    return viewModelBinding.read(spec);
  }
}
''');

  Future<void> test_initialization_callbacks_and_other_hosts() => check('''
class Child with ViewModel {}
final spec = ViewModelSpec(builder: Child.new);
class Page with ViewModelStateMixin {
  void initState() {
    viewModelBinding.listen(spec, onChanged: () {});
  }
  Object build(Object context) {
    void onTap() => viewModelBinding.listen(spec, onChanged: () {});
    return [onTap, () => viewModelBinding.listen(spec, onChanged: () {})];
  }
}
class Parent with ViewModel {
  Parent() {
    viewModelBinding.listen(spec, onChanged: () {});
  }
}
class Plain {
  final binding = ViewModelBinding();
  Object build() {
    binding.listen(spec, onChanged: () {});
    return Object();
  }
}
class Stream {
  void listen(void Function() onData) {}
}
Object get stream {
  Stream().listen(() {});
  return Object();
}
''');
}

@reflectiveTest
class InstanceHandoffTest extends _ViewModelTest {
  @override
  String get analysisRule => 'view_model_instance_handoff';

  Future<void> test_constructor_parameters() => check('''
class Child with ViewModel {}
class Page {
  final Child child;
  final Child? other;
  Page([[this.child]], {[[this.other]]});
}
class Service {
  final Object value;
  Service([[Child child]]) : value = child;
}
class Parent with ViewModel {
  Parent([[Child child]]);
}
class Base {
  Base([[Child child]]);
}
class Derived extends Base {
  Derived(super.child);
}
''');

  Future<void> test_specs_data_methods_and_type_parameters() => check('''
class Child with ViewModel {}
class Page {
  final ViewModelSpec<Child> spec;
  final String id;
  Page(this.spec, this.id);
  void render(Child child) {}
}
class Holder<T extends ViewModel> {
  Holder(T value);
}
''');
}

@reflectiveTest
class IdentityCollisionTest extends _ViewModelTest {
  @override
  String get analysisRule => 'view_model_identity_collision';

  Future<void> test_varying_arguments_and_distinct_specs() => check('''
class Item with ViewModel {
  Item(String id);
}
class Counter with ViewModel {}
final itemSpec = ViewModelSpec.arg<Item, String>(builder: Item.new);
final nullKey = ViewModelSpec.arg<Item, String>(
  builder: Item.new, key: (_) => null);
final aSpec = ViewModelSpec(builder: Counter.new);
final bSpec = ViewModelSpec<Counter>(builder: () => Counter());
class Page with ViewModelStateMixin {
  Item get first => viewModelBinding.watch(itemSpec('a'));
  Item get second => [[viewModelBinding.watch(itemSpec('b'))]];
  Item get third => [[viewModelBinding.read(nullKey('c'))]];
  Counter get a => viewModelBinding.read(aSpec);
  Counter get b => [[readViewModel(factory: bSpec)]];
  List<Item> items(List<String> ids) =>
      ids.map((id) => [[viewModelBinding.watch(itemSpec(id))]]).toList();
}
class Parent with ViewModel {
  Item item(String id) => [[viewModelBinding.read(itemSpec(id))]];
}
void main() {
  final binding = ViewModelBinding();
  for (final id in ['a', 'b']) {
    [[binding.read(itemSpec(id))]];
  }
}
''');

  Future<void> test_keys_repeated_arguments_and_separate_bindings() => check('''
class Item with ViewModel {
  Item(String id);
}
final keyed = ViewModelSpec.arg<Item, String>(
  builder: Item.new, key: (id) => id);
final unkeyed = ViewModelSpec.arg<Item, String>(builder: Item.new);
class Page with ViewModelStateMixin {
  final String id = 'a';
  Item get a => viewModelBinding.watch(unkeyed(id));
  Item get b => viewModelBinding.read(unkeyed(id));
  Object build(Object context) => viewModelBinding.watch(unkeyed(id));
  List<Item> all(List<String> ids) =>
      [for (final id in ids) viewModelBinding.watch(keyed(id))];
}
class Other with ViewModelStateMixin {
  Item get item => viewModelBinding.watch(unkeyed('b'));
}
Item resolve(ViewModelBinding binding, ViewModelSpecWithArg<Item, String> spec,
    String id) => binding.read(spec(id));
''');

  Future<void> test_imported_specs() async {
    newFile('$testPackageLibPath/specs.dart', '''
import 'package:view_model/view_model.dart';
class Item with ViewModel {
  Item(String id);
}
final unkeyed = ViewModelSpec.arg<Item, String>(builder: Item.new);
final keyed = ViewModelSpec.arg<Item, String>(
  builder: Item.new, key: (id) => id);
''');
    await check('''
import 'specs.dart';
class Page with ViewModelStateMixin {
  Item get a => viewModelBinding.watch(unkeyed('a'));
  Item get b => [[viewModelBinding.watch(unkeyed('b'))]];
  Item get c => viewModelBinding.watch(keyed('c'));
}
''');
  }
}

@reflectiveTest
class SelectorWithWatchTest extends _ViewModelTest {
  @override
  String get analysisRule => 'view_model_selector_with_watch';

  Future<void> test_fix_uses_read_1() async {
    await checkFix(
      ViewModelRuleKind.selectorWithWatch,
      '''
class Counter extends StateViewModel<int> {}
final spec = ViewModelSpec(builder: Counter.new);
class Page with ViewModelStateMixin {
  Object build() => StateViewModelValueWatcher(
    viewModel: [[viewModelBinding.watch(spec)]]);
}
''',
      '''
class Counter extends StateViewModel<int> {}
final spec = ViewModelSpec(builder: Counter.new);
class Page with ViewModelStateMixin {
  Object build() => StateViewModelValueWatcher(
    viewModel: viewModelBinding.read(spec));
}
''',
    );
  }

  Future<void> test_fix_uses_read_2() async {
    await checkFix(
      ViewModelRuleKind.selectorWithWatch,
      '''
class Counter extends StateViewModel<int> {}
final spec = ViewModelSpec(builder: Counter.new);
class Page with ViewModelStateMixin {
  Object build() => StateViewModelValueWatcher(
    viewModel: [[watchViewModel(factory: spec)]]);
}
''',
      '''
class Counter extends StateViewModel<int> {}
final spec = ViewModelSpec(builder: Counter.new);
class Page with ViewModelStateMixin {
  Object build() => StateViewModelValueWatcher(
    viewModel: readViewModel(factory: spec));
}
''',
    );
  }

  Future<void> test_fix_skips_watched_getters() =>
      checkFix(ViewModelRuleKind.selectorWithWatch, '''
class Counter extends StateViewModel<int> {}
final spec = ViewModelSpec(builder: Counter.new);
class Page with ViewModelStateMixin {
  Counter get watched => viewModelBinding.watch(spec);
  Object build() => StateViewModelValueWatcher(viewModel: [[watched]]);
}
''', null);

  Future<void> test_watched_view_models() => check('''
class Counter extends StateViewModel<int> {}
final spec = ViewModelSpec(builder: Counter.new);
class Page with ViewModelStateMixin {
  Counter get watched => viewModelBinding.watch(spec);
  Counter get reader => viewModelBinding.read(spec);
  Object build(Object context) {
    final local = viewModelBinding.watch(spec);
    return [
      StateViewModelValueWatcher(viewModel: [[viewModelBinding.watch(spec)]]),
      StateViewModelValueWatcher(viewModel: [[watched]]),
      StateViewModelValueWatcher(viewModel: [[local]]),
      StateViewModelValueWatcher(viewModel: [[watchViewModel(factory: spec)]]),
      StateViewModelValueWatcher(viewModel: reader),
      StateViewModelValueWatcher(viewModel: viewModelBinding.read(spec)),
    ];
  }
}
''');
}

@reflectiveTest
class UndisposedBindingTest extends _ViewModelTest {
  @override
  String get analysisRule => 'view_model_undisposed_binding';

  Future<void> test_undisposed_bindings() => check('''
class Child with ViewModel {}
class Boot extends ViewModelBinding {}
final spec = ViewModelSpec(builder: Child.new);
final global = [[ViewModelBinding()]];
final boot = [[Boot()]];
class Host {
  final binding = [[ViewModelBinding()]];
}
void main() {
  final local = [[ViewModelBinding()]];
  local.read(spec);
  [[ViewModelBinding()]].read(spec);
  [[ViewModelBinding()]];
}
''');

  Future<void> test_disposed_and_transferred_bindings() => check('''
class Child with ViewModel {}
final spec = ViewModelSpec(builder: Child.new);
void addTearDown(void Function() callback) {}
void setUp(void Function() callback) {}
void tearDown(void Function() callback) {}
void keep(ViewModelBinding binding) {}
class Host {
  final binding = ViewModelBinding();
  void dispose() => binding.dispose();
}
ViewModelBinding create() => ViewModelBinding();
void main() {
  late ViewModelBinding shared;
  setUp(() => shared = ViewModelBinding());
  tearDown(() => shared.dispose());
  final torn = ViewModelBinding();
  addTearDown(torn.dispose);
  final passed = ViewModelBinding();
  keep(passed);
  ViewModelBinding()..read(spec)..dispose();
  ViewModelBinding().dispose();
  keep(ViewModelBinding());
}
''');
}

@reflectiveTest
class TemporarySpecTest extends _ViewModelTest {
  @override
  String get analysisRule => 'view_model_temporary_spec';

  Future<void> test_temporary_specs() => check('''
class Child with ViewModel {}
class Item with ViewModel {
  Item(String id);
}
class ChildFactory extends ViewModelFactory<Child> {
  @override
  Child build() => Child();
}
final specs = <Object>[ [[ViewModelSpec(builder: Child.new)]] ];
ViewModelSpec<Child> make() => [[ViewModelSpec(builder: Child.new)]];
class Page with ViewModelStateMixin {
  final field = [[ViewModelSpec(builder: Child.new)]];
  ViewModelSpec<Child> create() {
    return [[ViewModelSpec(builder: Child.new)]];
  }
  Child get child =>
      viewModelBinding.watch([[ViewModelSpec(builder: Child.new)]]);
  Item get item => viewModelBinding.read(
      [[ViewModelSpec.arg<Item, String>(builder: Item.new)]]('a'));
  Child get compat =>
      watchViewModel(factory: [[ViewModelProvider(builder: Child.new)]]);
  Child get custom => viewModelBinding.read([[ChildFactory()]]);
  Object build(Object context) {
    final local = [[ViewModelSpec(builder: Child.new)]];
    viewModelBinding.listen(local, onChanged: () {});
    return ViewModelBuilder([[ViewModelSpec(builder: Child.new)]]);
  }
}
''');

  Future<void> test_fix_makes_instance_field_static_1() async {
    const source = '''
class Child with ViewModel {}
class Page with ViewModelStateMixin {
  final field = [[ViewModelSpec(builder: Child.new)]];
}
''';
    await checkFix(ViewModelRuleKind.temporarySpec, source, '''
class Child with ViewModel {}
class Page with ViewModelStateMixin {
  static final field = ViewModelSpec(builder: Child.new);
}
''');
  }

  Future<void> test_fix_makes_instance_field_static_2() async {
    const source = '''
class Child with ViewModel {}
class Page with ViewModelStateMixin {
  final field = [[ViewModelSpec(builder: Child.new)]];
}
''';
    await checkFix(ViewModelRuleKind.temporarySpec, source, null, fix: 1);
  }

  Future<void> test_fix_makes_instance_field_static_3() async {
    await checkFix(ViewModelRuleKind.temporarySpec, '''
class Child with ViewModel {}
class Page with ViewModelStateMixin {
  Child create() => Child();
  late final field = [[ViewModelSpec(builder: create)]];
}
''', null);
  }

  Future<void> test_fix_extracts_inline_specs_1() async {
    const source = '''
class Child with ViewModel {}
final _childSpec = Object();
class Page with ViewModelStateMixin {
  Child get child => viewModelBinding.watch([[ViewModelSpec(builder: Child.new)]]);
}
''';
    await checkFix(ViewModelRuleKind.temporarySpec, source, null);
  }

  Future<void> test_fix_extracts_inline_specs_2() async {
    const source = '''
class Child with ViewModel {}
final _childSpec = Object();
class Page with ViewModelStateMixin {
  Child get child => viewModelBinding.watch([[ViewModelSpec(builder: Child.new)]]);
}
''';
    await checkFix(ViewModelRuleKind.temporarySpec, source, '''
class Child with ViewModel {}
final _childSpec = Object();
class Page with ViewModelStateMixin {
  Child get child => viewModelBinding.watch(_childSpec2);
}

final _childSpec2 = ViewModelSpec(builder: Child.new);
''', fix: 1);
  }

  Future<void> test_fix_extracts_inline_specs_3() async {
    await checkFix(
      ViewModelRuleKind.temporarySpec,
      '''
class Item with ViewModel {
  Item(String id);
}
class Page with ViewModelStateMixin {
  Item get item => viewModelBinding.read(
      [[ViewModelSpec.arg<Item, String>(builder: Item.new)]]('a'));
}
''',
      '''
class Item with ViewModel {
  Item(String id);
}
class Page with ViewModelStateMixin {
  Item get item => viewModelBinding.read(
      _itemSpec('a'));
}

final _itemSpec = ViewModelSpec.arg<Item, String>(builder: Item.new);
''',
      fix: 1,
    );
  }

  Future<void> test_fix_extracts_inline_specs_4() async {
    await checkFix(
      ViewModelRuleKind.temporarySpec,
      '''
class Child with ViewModel {}
class ChildFactory extends ViewModelFactory<Child> {
  @override
  Child build() => Child();
}
class Page with ViewModelStateMixin {
  Child get child => viewModelBinding.read([[ChildFactory()]]);
}
''',
      '''
class Child with ViewModel {}
class ChildFactory extends ViewModelFactory<Child> {
  @override
  Child build() => Child();
}
class Page with ViewModelStateMixin {
  Child get child => viewModelBinding.read(_childFactory);
}

final _childFactory = ChildFactory();
''',
      fix: 1,
    );
  }

  Future<void> test_fix_does_not_extract_captured_scope_1() async {
    await checkFix(
      ViewModelRuleKind.temporarySpec,
      '''
class Child with ViewModel {}
ViewModelSpec<Child> make(Object key) =>
    [[ViewModelSpec(builder: Child.new, key: key)]];
''',
      null,
      fix: 1,
    );
  }

  Future<void> test_fix_does_not_extract_captured_scope_2() async {
    await checkFix(
      ViewModelRuleKind.temporarySpec,
      '''
class Child with ViewModel {}
class Page with ViewModelStateMixin {
  Child create() => Child();
  Child get child => viewModelBinding.read([[ViewModelSpec(builder: create)]]);
}
''',
      null,
      fix: 1,
    );
  }

  Future<void> test_fix_does_not_extract_captured_scope_3() async {
    await checkFix(
      ViewModelRuleKind.temporarySpec,
      '''
class Box<T> with ViewModel {}
class Page with ViewModelStateMixin {
  Box<T> box<T>() => viewModelBinding.read([[ViewModelSpec<Box<T>>(builder: Box<T>.new)]]);
}
''',
      null,
      fix: 1,
    );
  }

  Future<void> test_global_static_generic_and_proxy_specs() => check('''
class Child with ViewModel {}
class Box<T> with ViewModel {}
final spec = ViewModelSpec(builder: Child.new);
late final lateSpec = ViewModelSpec(builder: Child.new);
final argSpec = ViewModelSpec.arg<Child, int>(builder: (_) => Child());
final provider = ViewModelProvider(builder: Child.new);
class ChildFactory extends ViewModelFactory<Child> {
  @override
  Child build() => Child();
}
final childFactory = ChildFactory();
ViewModelSpec<Box<T>> boxSpec<T>() {
  return ViewModelSpec<Box<T>>(builder: () => Box<T>());
}
ViewModelSpec<Box<T>> shortBoxSpec<T>() =>
    ViewModelSpec<Box<T>>(builder: () => Box<T>());
class Specs {
  static final child = ViewModelSpec(builder: Child.new);
  static ViewModelSpec<Box<T>> box<T>() =>
      ViewModelSpec<Box<T>>(builder: () => Box<T>());
}
void main() {
  spec.setProxy(ViewModelSpec(builder: Child.new));
  ViewModelBinding().read(spec);
}
''');
}

@reflectiveTest
class CachedLookupTest extends _ViewModelTest {
  @override
  String get analysisRule => 'view_model_cached_lookup';

  Future<void> test_cached_queries() => check('''
class Child with ViewModel {}
final spec = ViewModelSpec(builder: Child.new);
class Page with ViewModelStateMixin {
  Child get a => [[viewModelBinding.readCached<Child>(key: 'a')]];
  Child? get b => [[viewModelBinding.maybeWatchCached<Child>(tag: 'b')]];
  List<Child> get c => [[viewModelBinding.readCachesByTag<Child>('c')]];
  Child get d => [[ViewModel.readCached<Child>(key: 'd')]];
  Child get e => viewModelBinding.read(spec);
}
''');
}
