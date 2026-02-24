import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:view_model/view_model.dart';

/// Test ViewModel that can trigger state changes at specific times
class DelayedStateViewModel extends StateViewModel<int> {
  DelayedStateViewModel({int initialValue = 0}) : super(state: initialValue);

  /// Increment the counter immediately
  void increment() {
    setState(state + 1);
  }

  /// Increment the counter after a delay
  Future<void> incrementDelayed([Duration delay = Duration.zero]) async {
    await Future.delayed(delay);
    setState(state + 1);
  }

  /// Increment multiple times rapidly to test timing issues
  void incrementRapidly(int times) {
    for (int i = 0; i < times; i++) {
      Future.microtask(() => setState(state + 1));
    }
  }
}

/// Test widget that can control its mounting state
class ControlledMountWidget extends StatefulWidget {
  final bool shouldMount;
  final VoidCallback? onViewModelCreated;

  const ControlledMountWidget({
    super.key,
    this.shouldMount = true,
    this.onViewModelCreated,
  });

  @override
  State<ControlledMountWidget> createState() => _ControlledMountWidgetState();
}

class _ControlledMountWidgetState extends State<ControlledMountWidget>
    with ViewModelStateMixin<ControlledMountWidget> {
  DelayedStateViewModel? viewModel;
  bool isInitialized = false;

  @override
  void initState() {
    super.initState();

    if (widget.shouldMount) {
      _initializeViewModel();
    }
  }

  void _initializeViewModel() {
    viewModel = viewModelBinding.watch<DelayedStateViewModel>(
      ViewModelSpec<DelayedStateViewModel>(
        builder: () => DelayedStateViewModel(),
      ),
    );
    isInitialized = true;
    widget.onViewModelCreated?.call();
  }

  void createViewModelLater() {
    if (!isInitialized) {
      setState(() {
        _initializeViewModel();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!isInitialized || viewModel == null) {
      return Scaffold(
        body: Column(
          children: [
            const Text('Widget not mounted'),
            ElevatedButton(
              onPressed: createViewModelLater,
              child: const Text('Mount ViewModel'),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: Column(
        children: [
          Text('Count: ${viewModel!.state}'),
          ElevatedButton(
            onPressed: viewModel!.increment,
            child: const Text('Increment'),
          ),
          ElevatedButton(
            onPressed: () => viewModel!.incrementDelayed(),
            child: const Text('Increment Delayed'),
          ),
          ElevatedButton(
            onPressed: () => viewModel!.incrementRapidly(3),
            child: const Text('Increment Rapidly'),
          ),
        ],
      ),
    );
  }
}

/// Widget that simulates unmounting during ViewModel state changes
class UnmountingWidget extends StatefulWidget {
  const UnmountingWidget({super.key});

  @override
  State<UnmountingWidget> createState() => _UnmountingWidgetState();
}

class _UnmountingWidgetState extends State<UnmountingWidget>
    with ViewModelStateMixin<UnmountingWidget> {
  late DelayedStateViewModel viewModel;
  bool shouldShow = true;

  @override
  void initState() {
    super.initState();
    viewModel = viewModelBinding.watch<DelayedStateViewModel>(
      ViewModelSpec<DelayedStateViewModel>(
        builder: () => DelayedStateViewModel(),
      ),
    );
  }

  void triggerUnmountAndStateChange() {
    // Trigger state change that will happen after unmounting
    viewModel.incrementDelayed(const Duration(milliseconds: 100));

    // Unmount the widget immediately
    setState(() {
      shouldShow = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!shouldShow) {
      return const Scaffold(
        body: Text('Widget unmounted'),
      );
    }

    return Scaffold(
      body: Column(
        children: [
          Text('Count: ${viewModel.state}'),
          ElevatedButton(
            onPressed: triggerUnmountAndStateChange,
            child: const Text('Unmount and Change State'),
          ),
        ],
      ),
    );
  }
}

void main() {
  group('SchedulerBinding PostFrameCallback Tests', () {
    testWidgets('should handle setState when widget is not mounted',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ControlledMountWidget(shouldMount: false),
        ),
      );

      // Initially widget is not mounted
      expect(find.text('Widget not mounted'), findsOneWidget);
      expect(find.text('Count: 0'), findsNothing);

      // Mount the ViewModel
      await tester.tap(find.text('Mount ViewModel'));
      await tester.pumpAndSettle();

      // Now widget should be mounted and showing count
      expect(find.text('Count: 0'), findsOneWidget);
      expect(find.text('Widget not mounted'), findsNothing);
    });

    testWidgets('should handle rapid state changes without errors',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ControlledMountWidget(shouldMount: true),
        ),
      );

      // Wait for widget to be fully mounted
      await tester.pumpAndSettle();
      expect(find.text('Count: 0'), findsOneWidget);

      // Trigger rapid state changes
      await tester.tap(find.text('Increment Rapidly'));
      await tester.pumpAndSettle();

      // Should handle all state changes without errors
      expect(find.text('Count: 3'), findsOneWidget);
    });

    testWidgets('should handle delayed state changes', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ControlledMountWidget(shouldMount: true),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Count: 0'), findsOneWidget);

      // Trigger delayed increment
      await tester.tap(find.text('Increment Delayed'));

      // Should still be 0 immediately
      expect(find.text('Count: 0'), findsOneWidget);

      // Wait for delayed increment to complete
      await tester.pumpAndSettle();
      expect(find.text('Count: 1'), findsOneWidget);
    });

    testWidgets('should handle state changes after widget unmounting',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: UnmountingWidget(),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Count: 0'), findsOneWidget);

      // Trigger unmount and delayed state change
      await tester.tap(find.text('Unmount and Change State'));
      await tester.pump();

      // Widget should be unmounted immediately
      expect(find.text('Widget unmounted'), findsOneWidget);
      expect(find.text('Count: 0'), findsNothing);

      // Wait for the delayed state change to complete
      // This should not cause any errors even though widget is unmounted
      await tester.pumpAndSettle(const Duration(milliseconds: 200));

      // Widget should still be unmounted without errors
      expect(find.text('Widget unmounted'), findsOneWidget);
    });

    testWidgets(
        'should use SchedulerBinding.addPostFrameCallback when context not '
        'mounted', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ControlledMountWidget(shouldMount: false),
        ),
      );

      // Mount ViewModel and immediately trigger state change
      await tester.tap(find.text('Mount ViewModel'));

      // Pump once to start the mounting process but not complete it
      await tester.pump();

      // Now complete the mounting process
      await tester.pumpAndSettle();

      // Should successfully show the mounted widget without errors
      expect(find.text('Count: 0'), findsOneWidget);
    });

    testWidgets('should prevent setState after dispose', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ControlledMountWidget(shouldMount: true),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Count: 0'), findsOneWidget);

      // Trigger a delayed state change
      await tester.tap(find.text('Increment Delayed'));

      // Immediately remove the widget
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Text('Different Widget')),
        ),
      );

      // Wait for the delayed operation to complete
      await tester.pumpAndSettle(const Duration(milliseconds: 200));

      // Should not cause any errors
      expect(find.text('Different Widget'), findsOneWidget);
    });
  });
}
