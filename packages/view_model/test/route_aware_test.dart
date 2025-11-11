/// RouteAware behavior tests for ViewModelStateMixin.
///
/// This test verifies that when a new route is pushed on top of a page
/// using `ViewModelStateMixin`, the page pauses rebuilds (ignores updates),
/// and when the top route is popped, it resumes and triggers a refresh.
///
/// The test uses a simple `CounterViewModel` and a `CounterPage` widget.
/// It asserts that updates made while covered do not reflect immediately,
/// and after popping the covering route, the underlying page refreshes to
/// show the latest state.
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

  /// Builds the widget tree showing current count and a button to push a route.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Counter')),
      body: Center(
        child: Text('${_vm.count}', key: const Key('counter-text')),
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('push-overlay-btn'),
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const OverlayPage()),
          );
        },
        child: const Icon(Icons.open_in_new),
      ),
    );
  }
}

/// A simple overlay page used to cover [CounterPage] during the test.
class OverlayPage extends StatelessWidget {
  const OverlayPage({super.key});

  /// Builds a minimal scaffold to act as a covering route.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Overlay')),
      body: Center(
        child: ElevatedButton(
          key: const Key('pop-overlay-btn'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Pop'),
        ),
      ),
    );
  }
}

/// Ensures route-aware pause/resume semantics:
/// - When a new route is pushed (didPushNext), underlying page pauses rebuilds.
/// - Updates while paused are ignored by the page.
/// - When the top route is popped (didPopNext), the page resumes and refreshes.
void main() {
  testWidgets(
      'ViewModelStateMixin pauses while covered and refreshes on return',
      (tester) async {
    // Build app with registered RouteObserver from ViewModelConfig.
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [ViewModel.config.getRouteObserver()],
        home: const CounterPage(),
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

    // Push overlay route to cover CounterPage (didPushNext => pause).
    await tester.tap(find.byKey(const Key('push-overlay-btn')));
    await tester.pumpAndSettle();
    expect(find.text('Overlay'), findsOneWidget);

    // While covered, perform an update; underlying page should ignore it.
    vm.increment(); // expected count becomes 2, but page is paused
    await tester.pump();

    // The underlying page's text '2' should not appear yet.
    expect(find.text('2'), findsNothing);

    // Pop overlay (didPopNext => resume + forced refresh).
    await tester.tap(find.byKey(const Key('pop-overlay-btn')));
    await tester.pumpAndSettle();

    // After resume, the page refreshes and shows the latest count (2).
    expect(find.text('2'), findsOneWidget);
  });
}
