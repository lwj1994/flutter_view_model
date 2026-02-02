import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:view_model/view_model.dart';

/// Counter ViewModel used for stateless mixin tests.
/// Provides simple increment to drive rebuilds.
class CounterViewModel extends StateViewModel<int> {
  CounterViewModel({int initialValue = 0}) : super(state: initialValue);

  /// Increments the counter state by one.
  void increment() {
    setState(state + 1);
  }
}

/// Stateless widget using ViewModelStatelessMixin.
/// Displays counter state and a button to increment.
// ignore: must_be_immutable
class CounterStatelessWidget extends StatelessWidget
    with ViewModelStatelessMixin {
  CounterStatelessWidget({super.key});
  late final vm = viewModelBinding.watch<CounterViewModel>(
    ViewModelSpec<CounterViewModel>(
      builder: () => CounterViewModel(),
    ),
  );

  /// Builds UI bound to CounterViewModel state.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Text('Count: ${vm.state}'),
          ElevatedButton(
            onPressed: vm.increment,
            child: const Text('Increment'),
          ),
        ],
      ),
    );
  }
}

/// Stateless widget that shares a ViewModel instance via a key.
/// First watch creates the instance, second watch reads cached one.

class SharedCountersStateless extends StatelessWidget
    with ViewModelStatelessMixin {
  SharedCountersStateless({super.key});
  static const sharedKey = 'shared_counter_key';
  late final vm1 = viewModelBinding.watch<CounterViewModel>(
    ViewModelSpec<CounterViewModel>(
      builder: () => CounterViewModel(initialValue: 5),
      key: sharedKey,
    ),
  );
  late final vm2 = viewModelBinding.watchCached<CounterViewModel>(
    key: sharedKey,
  );

  /// Builds two views bound to the same keyed ViewModel.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Text('A: ${vm1.state}'),
          Text('B: ${vm2.state}'),
          ElevatedButton(
            onPressed: vm1.increment,
            child: const Text('Inc A'),
          ),
          ElevatedButton(
            onPressed: vm2.increment,
            child: const Text('Inc B'),
          ),
        ],
      ),
    );
  }
}

void main() {
  group('ViewModelStatelessMixin', () {
    testWidgets('rebuilds when ViewModel state changes', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: CounterStatelessWidget()),
      );

      // Initial value should be 0.
      expect(find.text('Count: 0'), findsOneWidget);

      // Tap increment and verify UI updates.
      await tester.tap(find.text('Increment'));
      await tester.pump();
      expect(find.text('Count: 1'), findsOneWidget);
      expect(find.text('Count: 0'), findsNothing);
    });

    testWidgets('shares instance via key and both views update',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: SharedCountersStateless()),
      );

      // Initial value should be 5 in both views.
      expect(find.text('A: 5'), findsOneWidget);
      expect(find.text('B: 5'), findsOneWidget);

      // Increment via first view and verify both update.
      await tester.tap(find.text('Inc A'));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('A: 6'), findsOneWidget);
      expect(find.text('B: 6'), findsOneWidget);

      // Increment via second view and verify both update.
      await tester.tap(find.text('Inc B'));
      await tester.pump();
      expect(find.text('A: 7'), findsOneWidget);
      expect(find.text('B: 7'), findsOneWidget);
    });
  });
}
