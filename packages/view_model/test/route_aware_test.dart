/// Route visibility pause/resume tests for ViewModelStateMixin.
///
/// This test verifies manual pause/resume using `visibleListeners`:
/// - When `onPause()` is invoked, the page ignores ViewModel updates.
/// - When `onResume()` is invoked, the page refreshes once and reflects
///   the latest state.
///
/// The test uses a simple `CounterViewModel` and a `CounterPage` widget.
/// It asserts that updates made while paused do not reflect immediately,
/// and after resuming, the page shows the latest state.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:view_model/view_model.dart';

/// A minimal ViewModel implementation for testing route-aware pause/resume.
class CounterViewModel with ViewModel {
  int _count = 0;

  /// Returns current count value.
  int get count => _count;

  /// Increments the count and notifies listeners.
  void increment() {
    update(() => _count++);
  }
}

/// A page that watches [CounterViewModel] using ViewModelStateMixin.
///
/// It renders the current `count` as text, and exposes a button that pushes
/// an overlay route to simulate being covered by another page.
class CounterPage extends StatefulWidget {
  const CounterPage({super.key});

  @override
  State<CounterPage> createState() => _CounterPageState();
}

class _CounterPageState extends State<CounterPage> with ViewModelStateMixin {
  late CounterViewModel _vm;

  /// Initializes and watches the CounterViewModel instance.
  @override
  void initState() {
    super.initState();
    _vm = watchViewModel<CounterViewModel>(
      factory: DefaultViewModelFactory<CounterViewModel>(
        builder: () => CounterViewModel(),
        key: 'routeAware-counter',
      ),
    );
  }

  /// Builds the widget tree showing current count.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Counter')),
      body: Center(
        child: Text('${_vm.count}', key: const Key('counter-text')),
      ),
    );
  }
}

/// Ensures manual pause/resume semantics:
/// - When `onPause()` is called, underlying page pauses rebuilds.
/// - Updates while paused are ignored by the page.
/// - When `onResume()` is called, the page resumes and refreshes once.
void main() {
  testWidgets(
      'ViewModelStateMixin ignores updates while paused and refreshes on resume',
      (tester) async {
    // Build app.
    await tester.pumpWidget(
      const MaterialApp(
        home: CounterPage(),
      ),
    );

    // Initial count should be 0.
    expect(find.byKey(const Key('counter-text')), findsOneWidget);
    expect(find.text('0'), findsOneWidget);

    // Increment to 1 and verify rebuild.
    final vm =
        ViewModel.readCached<CounterViewModel>(key: 'routeAware-counter');
    vm.increment();
    await tester.pump();
    expect(find.text('1'), findsOneWidget);

    // Pause page manually.
    final state = tester.state(find.byType(CounterPage)) as _CounterPageState;
    state.attacher.viewModelVisibleListeners.onPause();
    await tester.pump();

    // While covered, perform an update; underlying page should ignore it.
    vm.increment(); // expected count becomes 2, but page is paused
    await tester.pump();

    // The underlying page's text '2' should not appear yet.
    expect(find.text('2'), findsNothing);

    // Resume page manually (forced refresh).
    state.attacher.viewModelVisibleListeners.onResume();
    await tester.pumpAndSettle();

    // After resume, the page refreshes and shows the latest count (2).
    expect(find.text('2'), findsOneWidget);
  });
}
