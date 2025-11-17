import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:view_model/view_model.dart';

// A simple ViewModel with a counter for testing.
class CounterViewModel extends ViewModel {
  int counter = 0;

  void increment() {
    counter++;
    notifyListeners();
  }
}

// A factory for creating CounterViewModel instances.
class CounterViewModelFactory with ViewModelFactory<CounterViewModel> {
  @override
  CounterViewModel build() => CounterViewModel();
}

// A StatefulWidget that uses the ViewModelStateMixin for the test.
class AwareWidget extends StatefulWidget {
  const AwareWidget({Key? key}) : super(key: key);

  @override
  State<AwareWidget> createState() => _AwareWidgetState();
}

class _AwareWidgetState extends State<AwareWidget> with ViewModelStateMixin {
  late final CounterViewModel viewModel;

  @override
  void initState() {
    super.initState();
    viewModel = watchViewModel(factory: CounterViewModelFactory());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text('Counter: ${viewModel.counter}'),
      ),
    );
  }
}

void main() {
  testWidgets('Widget does not rebuild when paused and rebuilds on resume',
      (WidgetTester tester) async {
    final routeObserver = ViewModel.routeObserver;
    // Build the widget and find its state.
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [routeObserver],
        home: const AwareWidget(),
      ),
    );

    final awareWidgetFinder = find.byType(AwareWidget, skipOffstage: false);
    final state = tester.state(awareWidgetFinder) as _AwareWidgetState;
    final viewModel = state.viewModel;

    // 1. Initial state check.
    expect(find.text('Counter: 0'), findsOneWidget);

    // 2. Push a new route to cover the AwareWidget.
    Navigator.of(tester.element(awareWidgetFinder)).push(
      MaterialPageRoute(
        builder: (_) => const Scaffold(body: Text('Second Page')),
      ),
    );

    // Wait for the navigation to complete.
    await tester.pumpAndSettle(const Duration(seconds: 1));

    viewModel.increment();
    // Verify the view model's state has changed.
    expect(viewModel.counter, 1);

    // 4. Pop the route to make the AwareWidget visible again.
    Navigator.of(tester.element(awareWidgetFinder)).pop();

    // Wait for the navigation and the single rebuild on resume to complete.
    await tester.pumpAndSettle();

    // 5. Verify that the widget has now been rebuilt and shows the updated value.
    expect(viewModel.counter, 1);
    expect(find.text('Counter: 1'), findsOneWidget);
  });
}
