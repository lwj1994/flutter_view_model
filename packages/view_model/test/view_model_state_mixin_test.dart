import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:view_model/view_model.dart';
import 'package:view_model/src/view_model/binding_zone.dart';
import 'package:view_model/src/view_model/state_store.dart';

// Test ViewModels
class CounterViewModel extends StateViewModel<int> {
  CounterViewModel({int initialValue = 0}) : super(state: initialValue);

  void increment() {
    setState(state + 1);
  }

  void decrement() {
    setState(state - 1);
  }

  void reset() {
    setState(0);
  }
}

class UserViewModel extends ViewModel {
  final String name;
  final int age;

  UserViewModel({required this.name, required this.age});

  @override
  String toString() => 'UserViewModel(name: $name, age: $age)';
}

// Test Widgets using ViewModelStateMixin
class CounterWidget extends StatefulWidget {
  final ViewModelSpec<CounterViewModel>? factory;
  final String? viewModelKey;
  final Object? tag;

  const CounterWidget({
    super.key,
    this.factory,
    this.viewModelKey,
    this.tag,
  });

  @override
  State<CounterWidget> createState() => _CounterWidgetState();
}

class _CounterWidgetState extends State<CounterWidget>
    with ViewModelStateMixin<CounterWidget> {
  late CounterViewModel viewModel;

  @override
  void initState() {
    super.initState();
    viewModel = viewModelBinding.watch<CounterViewModel>(
      widget.factory ??
          ViewModelSpec<CounterViewModel>(
            builder: () => CounterViewModel(),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Text('Count: ${viewModel.state}'),
          ElevatedButton(
            onPressed: viewModel.increment,
            child: const Text('Increment'),
          ),
          ElevatedButton(
            onPressed: viewModel.decrement,
            child: const Text('Decrement'),
          ),
          ElevatedButton(
            onPressed: viewModel.reset,
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}

class UserWidget extends StatefulWidget {
  final ViewModelSpec<UserViewModel>? factory;
  final String? viewModelKey;
  final Object? tag;

  const UserWidget({
    super.key,
    this.factory,
    this.viewModelKey,
    this.tag,
  });

  @override
  State<UserWidget> createState() => _UserWidgetState();
}

class _UserWidgetState extends State<UserWidget>
    with ViewModelStateMixin<UserWidget> {
  UserViewModel? viewModel;

  @override
  void initState() {
    super.initState();
    if (widget.factory != null) {
      viewModel = widget.factory != null
          ? viewModelBinding.watch<UserViewModel>(
              widget.factory!,
            )
          : viewModelBinding.watchCached(
              key: widget.viewModelKey,
              tag: widget.tag,
            );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Text(viewModel?.toString() ?? 'No ViewModel'),
    );
  }
}

// Widget for testing multiple ViewModels
class MultiViewModelWidget extends StatefulWidget {
  const MultiViewModelWidget({super.key});

  @override
  State<MultiViewModelWidget> createState() => _MultiViewModelWidgetState();
}

class _MultiViewModelWidgetState extends State<MultiViewModelWidget>
    with ViewModelStateMixin<MultiViewModelWidget> {
  late CounterViewModel counter1;
  late CounterViewModel counter2;
  late UserViewModel user;

  @override
  void initState() {
    super.initState();

    // Different counters with different keys
    counter1 = viewModelBinding.watch<CounterViewModel>(
      ViewModelSpec<CounterViewModel>(
        builder: () => CounterViewModel(initialValue: 10),
        key: 'counter1',
      ),
    );

    counter2 = viewModelBinding.watch<CounterViewModel>(
      ViewModelSpec<CounterViewModel>(
        builder: () => CounterViewModel(initialValue: 20),
        key: 'counter2',
      ),
    );

    // User with tag
    user = viewModelBinding.watch<UserViewModel>(
      ViewModelSpec<UserViewModel>(
        builder: () => UserViewModel(name: 'Alice', age: 25),
        tag: 'primary_user',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Text('Counter1: ${counter1.state}'),
          Text('Counter2: ${counter2.state}'),
          Text('User: ${user.name}, Age: ${user.age}'),
          ElevatedButton(
            onPressed: counter1.increment,
            child: const Text('Increment Counter1'),
          ),
          ElevatedButton(
            onPressed: counter2.increment,
            child: const Text('Increment Counter2'),
          ),
        ],
      ),
    );
  }
}

void main() {
  group('ViewModelStateMixin with ViewModelSpec', () {
    testWidgets('should create and watch ViewModel correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CounterWidget(),
        ),
      );

      // Find the counter text
      expect(find.text('Count: 0'), findsOneWidget);

      // Tap increment button
      await tester.tap(find.text('Increment'));
      await tester.pump();

      // Verify state updated
      expect(find.text('Count: 1'), findsOneWidget);
      expect(find.text('Count: 0'), findsNothing);
    });

    testWidgets('should handle custom factory correctly', (tester) async {
      final customFactory = ViewModelSpec<CounterViewModel>(
        builder: () => CounterViewModel(initialValue: 100),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CounterWidget(factory: customFactory),
        ),
      );

      // Should start with custom initial value
      expect(find.text('Count: 100'), findsOneWidget);

      await tester.tap(find.text('Increment'));
      await tester.pump();

      expect(find.text('Count: 101'), findsOneWidget);
    });

    testWidgets('should share ViewModel with same key', (tester) async {
      const sharedKey = 'shared_counter';

      final factory = ViewModelSpec<CounterViewModel>(
        builder: () => CounterViewModel(initialValue: 50),
        key: sharedKey,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Column(
            children: [
              Expanded(
                child: CounterWidget(
                  key: const Key('widget1'),
                  factory: factory,
                ),
              ),
              Expanded(
                child: CounterWidget(
                  key: const Key('widget2'),
                  factory: factory,
                ),
              ),
            ],
          ),
        ),
      );

      // Both widgets should show the same initial value
      expect(find.text('Count: 50'), findsNWidgets(2));

      // Find first increment button and tap it
      final incrementButtons = find.text('Increment');
      await tester.tap(incrementButtons.first);
      await tester.pump();

      // Both widgets should show the updated value since they share the same
      // ViewModel.
      expect(find.text('Count: 51'), findsNWidgets(2));
      expect(find.text('Count: 50'), findsNothing);
    });

    testWidgets('should handle tag-based ViewModel lookup', (tester) async {
      const userTag = 'test_user';
      final userFactory = ViewModelSpec<UserViewModel>(
        builder: () => UserViewModel(name: 'Bob', age: 30),
        tag: userTag,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: UserWidget(
            factory: userFactory,
            tag: userTag,
          ),
        ),
      );

      expect(find.text('UserViewModel(name: Bob, age: 30)'), findsOneWidget);
    });

    testWidgets('should handle multiple ViewModels in one widget',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MultiViewModelWidget(),
        ),
      );

      // Check initial values
      expect(find.text('Counter1: 10'), findsOneWidget);
      expect(find.text('Counter2: 20'), findsOneWidget);
      expect(find.text('User: Alice, Age: ${25}'), findsOneWidget);

      // Increment counter1
      await tester.tap(find.text('Increment Counter1'));
      await tester.pump();

      // Only counter1 should change
      expect(find.text('Counter1: 11'), findsOneWidget);
      expect(find.text('Counter2: 20'), findsOneWidget);

      // Increment counter2
      await tester.tap(find.text('Increment Counter2'));
      await tester.pump();

      // Now counter2 should also change
      expect(find.text('Counter1: 11'), findsOneWidget);
      expect(find.text('Counter2: 21'), findsOneWidget);
    });

    testWidgets('should handle readViewModel correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return StatefulBuilder(
                builder: (context, setState) {
                  return const CounterReadWidget();
                },
              );
            },
          ),
        ),
      );

      // Should display initial count
      expect(find.text('Read Count: 0'), findsOneWidget);

      // Tap the update button which uses readViewModel
      await tester.tap(find.text('Update via Read'));
      await tester.pump();

      // Should show updated count
      expect(find.text('Read Count: 1'), findsOneWidget);
    });

    testWidgets('should handle maybeWatchViewModel correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MaybeViewModelWidget(),
        ),
      );

      // Should show default text when no ViewModel found
      expect(find.text('No ViewModel found'), findsOneWidget);

      // Tap to create ViewModel
      await tester.tap(find.text('Create ViewModel'));
      await tester.pump();

      // Should now show ViewModel data
      expect(find.text('Count: 0'), findsOneWidget);
      expect(find.text('No ViewModel found'), findsNothing);
    });

    testWidgets('should properly dispose ViewModels', (tester) async {
      final factory = ViewModelSpec<CounterViewModel>(
        builder: () => CounterViewModel(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CounterWidget(factory: factory),
        ),
      );

      // Increment to verify ViewModel is working
      await tester.tap(find.text('Increment'));
      await tester.pump();
      expect(find.text('Count: 1'), findsOneWidget);

      // Remove the widget to trigger dispose
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Text('Empty')),
        ),
      );

      // Widget should be disposed without errors
      expect(find.text('Empty'), findsOneWidget);
    });

    testWidgets('maybeWatchCached returns null if not found', (tester) async {
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return const ViewModelBindingTestWidget();
          },
        ),
      );
    });
  });

  group('ViewModelBindingHandler', () {
    test('manages refs manually', () {
      final handler = ViewModelBindingHandler();
      final viewModelBinding = TestViewModelBinding();

      handler.addRef(viewModelBinding);
      expect(handler.binding, viewModelBinding);

      handler.removeRef(viewModelBinding);
      expect(() => handler.binding, throwsA(isA<ViewModelError>()));
    });

    test('runWithBinding sets zone value', () {
      final viewModelBinding = TestViewModelBinding();
      runWithBinding(() {
        final handler = ViewModelBindingHandler();
        // Should pick up from Zone
        expect(handler.binding, viewModelBinding);
      }, viewModelBinding);
    });

    test('dispose clears refs', () {
      final handler = ViewModelBindingHandler();
      final viewModelBinding = TestViewModelBinding();
      handler.addRef(viewModelBinding);

      handler.dispose();
      expect(() => handler.binding, throwsA(isA<ViewModelError>()));
    });
  });

  group('ViewModelBinding Mixin', () {
    test('isDisposed default false', () {
      final v = TestViewModelBinding();
      expect(v.isDisposed, false);
    });

    test('viewModelBinding getter returns self', () {
      final v = TestViewModelBinding();
      expect(v.exposedBinding, v);
    });
  });

  group('ViewModelBinding Mixin Coverage', () {
    test('performForAllViewModels', () {
      final v = TestViewModelBinding();
      final vm = v.watch(ViewModelSpec(builder: () => CounterViewModel()));

      int count = 0;
      v.performForAllViewModels((viewModel) {
        count++;
        expect(viewModel, vm);
      });

      expect(count, 1);
    });

    test('listen / listenState on ViewModelBinding', () async {
      final v = TestViewModelBinding();
      final factory = ViewModelSpec(builder: () => CounterViewModel());

      // Ensure VM is created and we have reference
      final vm = v.read(factory);

      bool called = false;
      v.listen(factory, onChanged: () {
        called = true;
      });

      vm.increment(); // triggers notifyListeners
      await Future.delayed(Duration.zero);

      expect(called, isTrue);

      // listenState
      bool stateCalled = false;
      v.listenState<CounterViewModel, int>(factory, onChanged: (p, n) {
        stateCalled = true;
      });

      vm.increment();
      await Future.delayed(Duration.zero);
      expect(stateCalled, isTrue);

      // listenStateSelect
      bool selectCalled = false;
      v.listenStateSelect<CounterViewModel, int, int>(factory,
          selector: (s) => s,
          onChanged: (p, n) {
            selectCalled = true;
          });

      vm.increment();
      await Future.delayed(Duration.zero);
      expect(selectCalled, isTrue);
    });

    test('maybeReadCached returns null on error', () {
      final v = TestViewModelBinding();
      expect(v.maybeReadCached<CounterViewModel>(key: 'missing'), isNull);
    });

    test('maybeWatchCached returns null on error', () {
      final v = TestViewModelBinding();
      expect(v.maybeWatchCached<CounterViewModel>(key: 'missing'), isNull);
    });
  });
}

class TestViewModelBinding with ViewModelBinding {
  ViewModelBinding get exposedBinding => viewModelBinding;
}

// Additional test widgets
class CounterReadWidget extends StatefulWidget {
  const CounterReadWidget({super.key});

  @override
  State<CounterReadWidget> createState() => _CounterReadWidgetState();
}

class _CounterReadWidgetState extends State<CounterReadWidget>
    with ViewModelStateMixin<CounterReadWidget> {
  CounterViewModel? viewModel;
  int displayCount = 0;

  @override
  void initState() {
    super.initState();
    // Create ViewModel that won't trigger rebuilds
    viewModel = viewModelBinding.read<CounterViewModel>(
      ViewModelSpec<CounterViewModel>(
        builder: () => CounterViewModel(),
        key: 'read_counter',
      ),
    );
    displayCount = viewModel!.state;
  }

  void updateCount() {
    viewModel!.increment();
    setState(() {
      displayCount = viewModel!.state;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Text('Read Count: $displayCount'),
          ElevatedButton(
            onPressed: updateCount,
            child: const Text('Update via Read'),
          ),
        ],
      ),
    );
  }
}

class MaybeViewModelWidget extends StatefulWidget {
  const MaybeViewModelWidget({super.key});

  @override
  State<MaybeViewModelWidget> createState() => _MaybeViewModelWidgetState();
}

class _MaybeViewModelWidgetState extends State<MaybeViewModelWidget>
    with ViewModelStateMixin<MaybeViewModelWidget> {
  CounterViewModel? viewModel;

  @override
  void initState() {
    super.initState();
    // Try to get ViewModel that doesn't exist
    viewModel = viewModelBinding.maybeWatchCached<CounterViewModel>(
      key: 'non_existent_key',
    );
  }

  void createViewModel() {
    setState(() {
      viewModel = viewModelBinding.watch<CounterViewModel>(
        ViewModelSpec<CounterViewModel>(
          builder: () => CounterViewModel(),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          if (viewModel != null)
            Text('Count: ${viewModel!.state}')
          else
            const Text('No ViewModel found'),
          ElevatedButton(
            onPressed: createViewModel,
            child: const Text('Create ViewModel'),
          ),
        ],
      ),
    );
  }
}

class ViewModelBindingTestWidget extends StatefulWidget {
  const ViewModelBindingTestWidget({super.key});

  @override
  _ViewModelBindingTestWidgetState createState() =>
      _ViewModelBindingTestWidgetState();
}

class _ViewModelBindingTestWidgetState extends State<ViewModelBindingTestWidget>
    with ViewModelStateMixin {
  @override
  void initState() {
    super.initState();
    // Test maybeWatchCachedViewModel
    final vm = maybeWatchCachedViewModel<CounterViewModel>(key: 'non_existent');
    assert(vm == null);

    // Test maybeReadCachedViewModel
    final vm2 = maybeReadCachedViewModel<CounterViewModel>(key: 'non_existent');
    assert(vm2 == null);
  }

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}
