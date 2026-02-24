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
}

void main() {
  group('StateViewModelValueWatcher', () {
    late TestViewModel viewModel;

    setUp(() {
      viewModel = TestViewModel();
    });

    testWidgets('builds the initial state correctly',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: StateViewModelValueWatcher<TestState>(
            viewModel: viewModel,
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
            viewModel: viewModel,
            selectors: [(state) => state.count],
            builder: (state) => Text('Count: ${state.count}'),
          ),
        ),
      );

      expect(find.text('Count: 0'), findsOneWidget);

      viewModel.increment();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Count: 1'), findsOneWidget);
    });

    testWidgets('does not rebuild when non-selected state changes',
        (WidgetTester tester) async {
      int buildCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: StateViewModelValueWatcher<TestState>(
            viewModel: viewModel,
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

      viewModel.increment();
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
            viewModel: viewModel,
            selectors: [(state) => state.count, (state) => state.name],
            builder: (state) =>
                Text('Count: ${state.count}, Name: ${state.name}'),
          ),
        ),
      );

      expect(find.text('Count: 0, Name: Initial'), findsOneWidget);

      viewModel.increment();
      await tester.pump();

      expect(find.text('Count: 1, Name: Initial'), findsOneWidget);

      viewModel.changeName('New Name');
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Count: 1, Name: New Name'), findsOneWidget);
    });

    testWidgets('handles viewModel change', (WidgetTester tester) async {
      final newViewModel = TestViewModel();

      await tester.pumpWidget(
        MaterialApp(
          home: StateViewModelValueWatcher<TestState>(
            viewModel: viewModel,
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
            viewModel: newViewModel,
            selectors: [(state) => state.count],
            builder: (state) => Text('Count: ${state.count}'),
          ),
        ),
      );

      // The widget should now reflect the state of the new view model.
      expect(find.text('Count: 0'), findsOneWidget);

      newViewModel.increment();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Count: 1'), findsOneWidget);

      // The old view model should no longer trigger rebuilds.
      viewModel.increment();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Count: 1'), findsOneWidget);
    });

    testWidgets('handles selectors change', (WidgetTester tester) async {
      var selectors = [(state) => state.count];

      await tester.pumpWidget(
        MaterialApp(
          home: StateViewModelValueWatcher<TestState>(
            viewModel: viewModel,
            selectors: selectors,
            builder: (state) =>
                Text('Count: ${state.count}, Name: ${state.name}'),
          ),
        ),
      );

      expect(find.text('Count: 0, Name: Initial'), findsOneWidget);

      viewModel.changeName('New Name');
      await tester.pump(const Duration(seconds: 1));

      // Should not rebuild because 'name' is not selected.
      expect(find.text('Count: 0, Name: Initial'), findsOneWidget);

      // Change selectors to include 'name'.
      selectors = [(state) => state.count, (state) => state.name];
      await tester.pumpWidget(
        MaterialApp(
          home: StateViewModelValueWatcher<TestState>(
            viewModel: viewModel,
            selectors: selectors,
            builder: (state) =>
                Text('Count: ${state.count}, Name: ${state.name}'),
          ),
        ),
      );

      viewModel.changeName('Another Name');
      await tester.pump(const Duration(seconds: 1));

      // Should rebuild now because 'name' is selected.
      expect(find.text('Count: 0, Name: Another Name'), findsOneWidget);
    });

    testWidgets('disposes listeners correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: StateViewModelValueWatcher<TestState>(
            viewModel: viewModel,
            selectors: [(state) => state.count],
            builder: (state) => Text('Count: ${state.count}'),
          ),
        ),
      );

      // Remove the widget from the tree.
      await tester.pumpWidget(Container());

      // The view model should not have any listeners.
      expect(viewModel.hasListeners, isFalse);
    });
  });
}
