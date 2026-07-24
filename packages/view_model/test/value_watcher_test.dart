import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:view_model/view_model.dart';

// A simple state class for testing.
class TestState {
  final int count;
  final String name;

  TestState({this.count = 0, this.name = 'Initial'});

  TestState copyWith({int? count, String? name}) {
    return TestState(
      count: count ?? this.count,
      name: name ?? this.name,
    );
  }
}

// A simple ViewModel for testing.
class TestViewModel extends StateViewModel<TestState> {
  TestViewModel() : super(state: TestState());

  void increment() {
    setState(state.copyWith(count: state.count + 1));
  }

  void changeName(String newName) {
    setState(state.copyWith(name: newName));
  }

  void setValues({int? count, String? name}) {
    setState(state.copyWith(count: count, name: name));
  }
}

ViewModelSpec<TestViewModel> _testViewModelSpec(String key) {
  return ViewModelSpec<TestViewModel>(
    builder: () => TestViewModel(),
    key: key,
  );
}

class _TestViewModelOwner with ViewModelBinding {
  _TestViewModelOwner(this.spec);

  final ViewModelSpec<TestViewModel> spec;

  TestViewModel get viewModel => viewModelBinding.read(spec);
}

void main() {
  group('StateViewModelSelector', () {
    late _TestViewModelOwner owner;

    setUp(() {
      owner = _TestViewModelOwner(
        _testViewModelSpec('state-view-model-selector'),
      );
    });

    tearDown(() => owner.dispose());

    testWidgets('builds and updates one typed selected value', (tester) async {
      var buildCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: StateViewModelSelector<TestState, int>(
            viewModel: owner.viewModel,
            selector: (state) => state.count,
            builder: (context, count) {
              buildCount++;
              return Text('Count: $count');
            },
          ),
        ),
      );

      expect(find.text('Count: 0'), findsOneWidget);
      owner.viewModel.changeName('Unselected');
      await tester.pump();
      expect(buildCount, 1);

      owner.viewModel.increment();
      await tester.pump();
      expect(find.text('Count: 1'), findsOneWidget);
      expect(buildCount, 2);
    });

    testWidgets('supports a typed record as one update boundary',
        (tester) async {
      var buildCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: StateViewModelSelector<TestState, ({int count, String name})>(
            viewModel: owner.viewModel,
            selector: (state) => (count: state.count, name: state.name),
            builder: (context, value) {
              buildCount++;
              return Text('${value.count}: ${value.name}');
            },
          ),
        ),
      );

      owner.viewModel.setValues(count: 1, name: 'Updated');
      await tester.pump();

      expect(find.text('1: Updated'), findsOneWidget);
      expect(buildCount, 2);
    });

    testWidgets('uses selected-value equality', (tester) async {
      var buildCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: StateViewModelSelector<TestState, int>(
            viewModel: owner.viewModel,
            selector: (state) => state.count,
            equals: (previous, current) => previous.isEven == current.isEven,
            builder: (context, count) {
              buildCount++;
              return Text('Count: $count');
            },
          ),
        ),
      );

      owner.viewModel.setValues(count: 2);
      await tester.pump();
      expect(buildCount, 1);
      expect(find.text('Count: 0'), findsOneWidget);

      owner.viewModel.setValues(count: 3);
      await tester.pump();
      expect(buildCount, 2);
      expect(find.text('Count: 3'), findsOneWidget);
    });

    testWidgets('resubscribes when the ViewModel changes', (tester) async {
      final otherOwner = _TestViewModelOwner(
        _testViewModelSpec('state-view-model-selector-other'),
      );
      addTearDown(otherOwner.dispose);
      otherOwner.viewModel.setValues(count: 10);

      Widget buildWith(_TestViewModelOwner currentOwner) {
        return MaterialApp(
          home: StateViewModelSelector<TestState, int>(
            viewModel: currentOwner.viewModel,
            selector: (state) => state.count,
            builder: (context, count) => Text('Count: $count'),
          ),
        );
      }

      await tester.pumpWidget(buildWith(owner));
      await tester.pumpWidget(buildWith(otherOwner));
      expect(find.text('Count: 10'), findsOneWidget);

      owner.viewModel.increment();
      await tester.pump();
      expect(find.text('Count: 10'), findsOneWidget);

      otherOwner.viewModel.increment();
      await tester.pump();
      expect(find.text('Count: 11'), findsOneWidget);
    });
  });

  group('StateViewModelValueWatcher', () {
    late _TestViewModelOwner owner;

    setUp(() {
      owner = _TestViewModelOwner(
        _testViewModelSpec('state-view-model-value-watcher'),
      );
    });

    tearDown(() => owner.dispose());

    testWidgets('builds the initial state correctly',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: StateViewModelValueWatcher<TestState>(
            viewModel: owner.viewModel,
            selectors: const [],
            builder: (state) => Text('Count: ${state.count}'),
          ),
        ),
      );

      expect(find.text('Count: 0'), findsOneWidget);
    });

    testWidgets('rebuilds when selected state changes',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: StateViewModelValueWatcher<TestState>(
            viewModel: owner.viewModel,
            selectors: [(state) => state.count],
            builder: (state) => Text('Count: ${state.count}'),
          ),
        ),
      );

      expect(find.text('Count: 0'), findsOneWidget);

      owner.viewModel.increment();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Count: 1'), findsOneWidget);
    });

    testWidgets('does not rebuild when non-selected state changes',
        (WidgetTester tester) async {
      int buildCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: StateViewModelValueWatcher<TestState>(
            viewModel: owner.viewModel,
            selectors: [(state) => state.name],
            builder: (state) {
              buildCount++;
              return Text('Name: ${state.name}');
            },
          ),
        ),
      );

      expect(buildCount, 1);
      expect(find.text('Name: Initial'), findsOneWidget);

      owner.viewModel.increment();
      await tester.pump(const Duration(seconds: 1));

      // The builder should not be called again because the 'name' did not
      // change.
      expect(buildCount, 1);
      expect(find.text('Name: Initial'), findsOneWidget);
    });

    testWidgets('rebuilds when one of multiple selectors changes',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: StateViewModelValueWatcher<TestState>(
            viewModel: owner.viewModel,
            selectors: [(state) => state.count, (state) => state.name],
            builder: (state) =>
                Text('Count: ${state.count}, Name: ${state.name}'),
          ),
        ),
      );

      expect(find.text('Count: 0, Name: Initial'), findsOneWidget);

      owner.viewModel.increment();
      await tester.pump();

      expect(find.text('Count: 1, Name: Initial'), findsOneWidget);

      owner.viewModel.changeName('New Name');
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Count: 1, Name: New Name'), findsOneWidget);
    });

    testWidgets('handles viewModel change', (WidgetTester tester) async {
      final newOwner = _TestViewModelOwner(
        _testViewModelSpec('state-view-model-value-watcher-other'),
      );
      addTearDown(newOwner.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: StateViewModelValueWatcher<TestState>(
            viewModel: owner.viewModel,
            selectors: [(state) => state.count],
            builder: (state) => Text('Count: ${state.count}'),
          ),
        ),
      );

      expect(find.text('Count: 0'), findsOneWidget);

      // Change the viewModel instance
      await tester.pumpWidget(
        MaterialApp(
          home: StateViewModelValueWatcher<TestState>(
            viewModel: newOwner.viewModel,
            selectors: [(state) => state.count],
            builder: (state) => Text('Count: ${state.count}'),
          ),
        ),
      );

      // The widget should now reflect the state of the new view model.
      expect(find.text('Count: 0'), findsOneWidget);

      newOwner.viewModel.increment();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Count: 1'), findsOneWidget);

      // The old view model should no longer trigger rebuilds.
      owner.viewModel.increment();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Count: 1'), findsOneWidget);
    });

    testWidgets('handles selectors change', (WidgetTester tester) async {
      var selectors = [(state) => state.count];

      await tester.pumpWidget(
        MaterialApp(
          home: StateViewModelValueWatcher<TestState>(
            viewModel: owner.viewModel,
            selectors: selectors,
            builder: (state) =>
                Text('Count: ${state.count}, Name: ${state.name}'),
          ),
        ),
      );

      expect(find.text('Count: 0, Name: Initial'), findsOneWidget);

      owner.viewModel.changeName('New Name');
      await tester.pump(const Duration(seconds: 1));

      // Should not rebuild because 'name' is not selected.
      expect(find.text('Count: 0, Name: Initial'), findsOneWidget);

      // Change selectors to include 'name'.
      selectors = [(state) => state.count, (state) => state.name];
      await tester.pumpWidget(
        MaterialApp(
          home: StateViewModelValueWatcher<TestState>(
            viewModel: owner.viewModel,
            selectors: selectors,
            builder: (state) =>
                Text('Count: ${state.count}, Name: ${state.name}'),
          ),
        ),
      );

      owner.viewModel.changeName('Another Name');
      await tester.pump(const Duration(seconds: 1));

      // Should rebuild now because 'name' is selected.
      expect(find.text('Count: 0, Name: Another Name'), findsOneWidget);
    });

    testWidgets('disposes listeners correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: StateViewModelValueWatcher<TestState>(
            viewModel: owner.viewModel,
            selectors: [(state) => state.count],
            builder: (state) => Text('Count: ${state.count}'),
          ),
        ),
      );

      // Remove the widget from the tree.
      await tester.pumpWidget(Container());

      // The view model should not have any listeners.
      expect(owner.viewModel.hasListeners, isFalse);
    });
  });
}
