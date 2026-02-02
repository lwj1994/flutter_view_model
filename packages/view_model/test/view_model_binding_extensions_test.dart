import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:view_model/view_model.dart';
import 'package:view_model/src/get_instance/manager.dart';

// Helper ViewModels
class TestViewModel extends ViewModel {
  int count = 0;
  void increment() {
    count++;
    notifyListeners();
  }

  @override
  String toString() => '$count';
}

class TestStateViewModel extends StateViewModel<int> {
  TestStateViewModel(int initial) : super(state: initial);
  void increment() => setState(state + 1);
}

// Widget for StateViewModelBindingExtension
class TestStateMixinWidget<T extends ViewModel> extends StatefulWidget {
  final ViewModelSpec<T> provider;
  final Function(T vm)? onViewModel;
  final Function(_TestStateMixinWidgetState<T> state)? onState;

  const TestStateMixinWidget({
    super.key,
    required this.provider,
    this.onViewModel,
    this.onState,
  });

  @override
  State<TestStateMixinWidget<T>> createState() =>
      _TestStateMixinWidgetState<T>();
}

class _TestStateMixinWidgetState<T extends ViewModel>
    extends State<TestStateMixinWidget<T>> with ViewModelStateMixin {
  late T vm;

  @override
  void initState() {
    super.initState();
    // Test watchViewModel extension
    vm = watchViewModel(factory: widget.provider);
    widget.onViewModel?.call(vm);
  }

  @override
  Widget build(BuildContext context) {
    widget.onState?.call(this);
    // Assuming T has toString()
    return Text('${vm.toString()}');
  }
}

// Widget for StatelessWidgetViewModelBindingExtension
class TestStatelessMixinWidget<T extends ViewModel> extends StatelessWidget
    with ViewModelStatelessMixin {
  final ViewModelSpec<T> provider;
  final Function(T vm)? onViewModel;
  final Function(TestStatelessMixinWidget<T> widget)? onWidget;

  TestStatelessMixinWidget({
    super.key,
    required this.provider,
    this.onViewModel,
    this.onWidget,
  });

  @override
  Widget build(BuildContext context) {
    // Test watchViewModel extension
    final vm = watchViewModel(factory: provider);
    onViewModel?.call(vm);
    onWidget?.call(this);
    return Text('${vm.toString()}');
  }
}

// ViewModel for ViewModelViewModelBindingExtension
class ParentViewModel extends ViewModel {
  late TestViewModel childVM;

  void init(ViewModelSpec<TestViewModel> provider) {
    // Test watchViewModel extension (although unusual for VM to watch, it registers dependency)
    childVM = watchViewModel(factory: provider);
  }

  TestViewModel readChild(ViewModelSpec<TestViewModel> provider) {
    // Test readViewModel extension
    return readViewModel(factory: provider);
  }

  // Helpers for other extensions
  TestViewModel watchCached(String key) {
    return watchCachedViewModel<TestViewModel>(key: key);
  }

  TestViewModel? maybeWatchCached(String key) {
    return maybeWatchCachedViewModel<TestViewModel>(key: key);
  }

  @override
  String toString() => 'ParentViewModel';
}

void main() {
  group('ViewModelBinding Extensions Coverage', () {
    // 1. Test StateViewModelBindingExtension
    testWidgets('StateViewModelBindingExtension methods work correctly',
        (tester) async {
      final provider = ViewModelSpec(builder: () => TestViewModel());
      TestViewModel? capturedVM;

      await tester.pumpWidget(MaterialApp(
        home: TestStateMixinWidget<TestViewModel>(
          provider: provider,
          onViewModel: (vm) => capturedVM = vm,
          onState: (state) {
            // Test readViewModel
            final read = state.readViewModel(factory: provider);
            expect(read, equals(state.vm));

            // Test maybeReadCachedViewModel
            final missing = state.maybeReadCachedViewModel<TestViewModel>(
                key: 'missing_state_key');
            expect(missing, isNull);

            // Test maybeWatchCachedViewModel
            final missingWatch = state.maybeWatchCachedViewModel<TestViewModel>(
                key: 'missing_state_watch_key');
            expect(missingWatch, isNull);
          },
        ),
      ));

      expect(find.text('0'), findsOneWidget);
      expect(capturedVM, isNotNull);

      // Test that update triggers rebuild
      capturedVM!.increment();
      await tester.pump();
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('StateViewModelBindingExtension cached methods',
        (tester) async {
      // Pre-populate a cached ViewModel
      final vm = TestViewModel();
      const key = 'cached_key';

      // Ensure it's created/cached
      instanceManager.getNotifier(
        factory: InstanceFactory(
          builder: () => vm,
          arg: const InstanceArg(key: key),
        ),
      );

      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) {
          return const TestStateCachedWidget(keyName: key);
        }),
      ));

      expect(find.text('0'), findsOneWidget);
      vm.increment();
      await tester.pump();
      expect(find.text('1'), findsOneWidget);
    });

    // 2. Test StatelessWidgetViewModelBindingExtension
    testWidgets('StatelessWidgetViewModelBindingExtension watch works',
        (tester) async {
      final provider = ViewModelSpec(builder: () => TestViewModel());
      TestViewModel? capturedVM;

      await tester.pumpWidget(MaterialApp(
        home: TestStatelessMixinWidget<TestViewModel>(
          provider: provider,
          onViewModel: (vm) => capturedVM = vm,
        ),
      ));

      expect(find.text('0'), findsOneWidget);
      expect(capturedVM, isNotNull);

      capturedVM!.increment();
      await tester.pump();
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('StatelessWidgetViewModelBindingExtension read and cache works',
        (tester) async {
      final keyedProvider = ViewModelSpec(
          builder: () => TestViewModel(), key: 'stateless_read_key');
      TestViewModel? capturedVM;

      await tester.pumpWidget(MaterialApp(
        home: TestStatelessMixinWidget<TestViewModel>(
            provider: keyedProvider,
            onViewModel: (vm) => capturedVM = vm,
            onWidget: (widget) {
              final read = widget.readViewModel(factory: keyedProvider);
              expect(read, equals(capturedVM));

              final missing = widget.maybeReadCachedViewModel<TestViewModel>(
                  key: 'missing_stateless_key');
              expect(missing, isNull);

              final missingWatch =
                  widget.maybeWatchCachedViewModel<TestViewModel>(
                      key: 'missing_stateless_watch_key');
              expect(missingWatch, isNull);
            }),
      ));

      expect(find.text('0'), findsOneWidget);
      capturedVM!.increment();
      await tester.pump();
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('StatelessWidgetViewModelBindingExtension cached methods',
        (tester) async {
      final vm = TestViewModel();
      const key = 'cached_stateless_key';

      // Ensure it's created/cached
      instanceManager.getNotifier(
        factory: InstanceFactory(
          builder: () => vm,
          arg: const InstanceArg(key: key),
        ),
      );

      await tester.pumpWidget(MaterialApp(
        home: TestStatelessCachedWidget(keyName: key),
      ));

      expect(find.text('0'), findsOneWidget);
      vm.increment();
      await tester.pump();
      expect(find.text('1'), findsOneWidget);
    });

    // 3. Test ViewModelViewModelBindingExtension
    testWidgets('ViewModelViewModelBindingExtension methods work correctly',
        (tester) async {
      final childProvider = ViewModelSpec(builder: () => TestViewModel());
      final parentProvider = ViewModelSpec(builder: () => ParentViewModel());

      ParentViewModel? capturedParent;

      await tester.pumpWidget(MaterialApp(
        home: TestStateMixinWidget<ParentViewModel>(
          provider: parentProvider,
          onViewModel: (vm) {
            capturedParent = vm;
            // Trigger the internal watch
            vm.init(childProvider);
          },
        ),
      ));

      expect(capturedParent, isNotNull);
      expect(capturedParent!.childVM, isNotNull);
      expect(capturedParent!.childVM.count, 0);

      // Test readViewModel inside parent
      final readChild = capturedParent!.readChild(childProvider);
      expect(readChild, equals(capturedParent!.childVM));

      // Test maybeReadCachedViewModel
      const key = 'vm_extension_key_2';
      final keyedProvider =
          ViewModelSpec(builder: () => TestViewModel(), key: key);

      // We need to create the keyed VM first.
      // Since we are inside a widget context, we can use capturedParent to watch/create it.
      final vm = capturedParent!.watchViewModel(factory: keyedProvider);

      final cached =
          capturedParent!.readCachedViewModel<TestViewModel>(key: key);
      expect(cached, equals(vm));

      final maybeCached =
          capturedParent!.maybeReadCachedViewModel<TestViewModel>(key: key);
      expect(maybeCached, equals(vm));

      final maybeMissing = capturedParent!
          .maybeReadCachedViewModel<TestViewModel>(key: 'missing_key');
      expect(maybeMissing, isNull);

      // Test watchCachedViewModel
      final watchedCached = capturedParent!.watchCached(key);
      expect(watchedCached, equals(vm));

      // Test maybeWatchCachedViewModel
      final maybeWatch = capturedParent!.maybeWatchCached(key);
      expect(maybeWatch, equals(vm));

      final maybeWatchMissing =
          capturedParent!.maybeWatchCached('missing_watch_key');
      expect(maybeWatchMissing, isNull);

      // Test recycleViewModel (ViewModel extension)
      final oldChild = capturedParent!.childVM;
      capturedParent!.recycleViewModel(oldChild);
      // Since ParentViewModel watches childProvider, it should have a new instance now if it was in build,
      // but here it was in init(). In real use, watch is usually in build or reactive.
    });

    testWidgets('Extensions listen and recycle coverage', (tester) async {
      final provider =
          ViewModelSpec(builder: () => TestViewModel(), key: 'listen_test_vm');
      final stateProvider = ViewModelSpec(
          builder: () => TestStateViewModel(0), key: 'listen_test_state_vm');

      int stateListenCount = 0;
      int selectChangeCount = 0;
      int statelessListenCount = 0;

      TestViewModel? capturedVM;
      TestStateViewModel? capturedSVM;

      bool registered = false;
      await tester.pumpWidget(MaterialApp(
        home: Column(
          children: [
            TestStateMixinWidget<TestViewModel>(
              provider: provider,
              onState: (state) {
                if (registered) return;
                registered = true;
                state.listenViewModelState<TestStateViewModel, int>(
                  factory: stateProvider,
                  onChanged: (p, s) => stateListenCount++,
                );
                state.listenViewModelStateSelect<TestStateViewModel, int, bool>(
                  factory: stateProvider,
                  selector: (s) => s > 0,
                  onChanged: (p, s) => selectChangeCount++,
                );
              },
            ),
            TestStatelessMixinWidget<TestViewModel>(
              provider: provider,
              onViewModel: (vm) => capturedVM = vm,
              onWidget: (widget) {
                widget.listenViewModel(
                  factory: provider,
                  onChanged: () => statelessListenCount++,
                );
                // Also capture StateViewModel for triggered changes
                capturedSVM = widget.readViewModel(factory: stateProvider);
              },
            ),
          ],
        ),
      ));

      expect(capturedVM, isNotNull);
      expect(capturedSVM, isNotNull);

      print('Stateless listen count: $statelessListenCount');
      capturedVM!.increment();
      print('Stateless listen count after increment: $statelessListenCount');
      expect(statelessListenCount, 1);

      print('State listen count: $stateListenCount');
      capturedSVM!.increment(); // 0 -> 1
      await tester.pump(); // wait for state stream
      print('State listen count after increment: $stateListenCount');
      expect(stateListenCount, 1);
      expect(selectChangeCount, 1);

      capturedSVM!.increment(); // 1 -> 2
      await tester.pump();
      expect(stateListenCount, 2);
      expect(selectChangeCount, 1); // selector unchanged (still > 0)
    });

    testWidgets('Additional extension coverage', (tester) async {
      final provider = ViewModelSpec(builder: () => TestViewModel());
      final stateProvider = ViewModelSpec(builder: () => TestStateViewModel(0));

      // 1. StateViewModelBindingExtension: listenViewModel, recycleViewModel
      await tester.pumpWidget(MaterialApp(
        home: TestStateMixinWidget<TestViewModel>(
          provider: provider,
          onState: (state) {
            state.listenViewModel(factory: provider, onChanged: () {});
            final vm = state.readViewModel(factory: provider);
            state.recycleViewModel(vm);
          },
        ),
      ));
      await tester.pump();

      // 2. StatelessWidgetViewModelBindingExtension: listenViewModelState, listenViewModelStateSelect, recycleViewModel
      await tester.pumpWidget(MaterialApp(
        home: TestStatelessMixinWidget<TestViewModel>(
          provider: provider,
          onWidget: (widget) {
            widget.listenViewModelState<TestStateViewModel, int>(
              factory: stateProvider,
              onChanged: (p, c) {},
            );
            widget.listenViewModelStateSelect<TestStateViewModel, int, bool>(
              factory: stateProvider,
              selector: (s) => s > 0,
              onChanged: (p, c) {},
            );
            final vm = widget.readViewModel(factory: provider);
            widget.recycleViewModel(vm);
          },
        ),
      ));
      await tester.pump();

      // 3. ViewModelViewModelBindingExtension: listenViewModel, listenViewModelState, listenViewModelStateSelect
      final parentProvider = ViewModelSpec(builder: () => ParentViewModel());

      await tester.pumpWidget(MaterialApp(
        home: TestStateMixinWidget<ParentViewModel>(
          provider: parentProvider,
          onViewModel: (vm) {
            vm.listenViewModel(factory: provider, onChanged: () {});
            vm.listenViewModelState<TestStateViewModel, int>(
              factory: stateProvider,
              onChanged: (p, c) {},
            );
            vm.listenViewModelStateSelect<TestStateViewModel, int, bool>(
              factory: stateProvider,
              selector: (s) => s > 0,
              onChanged: (p, c) {},
            );
          },
        ),
      ));
      await tester.pump();
    });
  });
}

// Helper widgets for cached tests
class TestStateCachedWidget extends StatefulWidget {
  final String keyName;
  const TestStateCachedWidget({super.key, required this.keyName});
  @override
  State<TestStateCachedWidget> createState() => _TestStateCachedWidgetState();
}

class _TestStateCachedWidgetState extends State<TestStateCachedWidget>
    with ViewModelStateMixin {
  late TestViewModel vm;

  @override
  void initState() {
    super.initState();
    // Test readCachedViewModel extension
    vm = readCachedViewModel<TestViewModel>(key: widget.keyName);
  }

  @override
  Widget build(BuildContext context) {
    // Test watchCachedViewModel extension
    watchCachedViewModel<TestViewModel>(key: widget.keyName);
    return Text('${vm.count}');
  }
}

class TestStatelessCachedWidget extends StatelessWidget
    with ViewModelStatelessMixin {
  final String keyName;
  TestStatelessCachedWidget({super.key, required this.keyName});

  @override
  Widget build(BuildContext context) {
    // Test readCachedViewModel extension
    final readVm = readCachedViewModel<TestViewModel>(key: keyName);

    // Test watchCachedViewModel extension
    final vm = watchCachedViewModel<TestViewModel>(key: keyName);

    assert(readVm == vm);

    return Text('${vm.count}');
  }
}
