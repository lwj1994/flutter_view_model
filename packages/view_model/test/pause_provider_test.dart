import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:view_model/src/view_model/pause_provider.dart';
import 'package:view_model/view_model.dart';

// Define a simple ViewModel for testing
class TestViewModel extends ChangeNotifierViewModel {
  int _count = 0;
  int get count => _count;

  void increment() {
    _count++;
    notifyListeners();
  }
}

class TestTickerWidget extends StatefulWidget {
  const TestTickerWidget({super.key});

  @override
  State<TestTickerWidget> createState() => _TestTickerWidgetState();
}

class _TestTickerWidgetState extends State<TestTickerWidget>
    with ViewModelStateMixin {
  final provider = TickModePauseProvider();
  bool tickerEnabled = true;
  @override
  void initState() {
    super.initState();
    addViewModelPauseProvider(provider);
    // _animationController = AnimationController(
    //   vsync: this,
    //   duration: const Duration(seconds: 1),
    // );
  }

  @override
  void dispose() {
    // _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Column(
        children: [
          TextButton(
            key: const Key('Toggle Ticker'),
            onPressed: () {
              print("_TestTickerWidgetState Toggle Ticker pressed");
              setState(() => tickerEnabled = !tickerEnabled);
            },
            child: const Text('Toggle Ticker'),
          ),
          TickerMode(enabled: tickerEnabled, child: const SubWidget()),
        ],
      ),
    );
  }
}

class SubWidget extends StatefulWidget {
  const SubWidget({super.key});

  @override
  State<SubWidget> createState() => _SubWidgetState();
}

class _SubWidgetState extends State<SubWidget> with ViewModelStateMixin {
  late final TestViewModel viewModel;

  @override
  void initState() {
    super.initState();
    final notifier = TickerMode.getNotifier(context);
    notifier.addListener(() {
      print("_SubWidgetState TickerMode changed to ${notifier.value}");
    });
    viewModel = watchViewModel(
        factory: DefaultViewModelFactory(builder: () => TestViewModel()));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('Count: ${viewModel.count}'),
        TextButton(
          onPressed: () {
            print("_SubWidgetState Increment pressed");
            viewModel.increment();
          },
          child: const Text('Increment'),
        ),
      ],
    );
  }
}

void main() {
  group('TickMode Widget with ViewModel', () {
    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      ViewModel.initialize(config: ViewModelConfig(isLoggingEnabled: true));
    });
    testWidgets('ViewModel does not update when TickerMode is disabled',
        (tester) async {
      await tester.pumpWidget(const TestTickerWidget());

      // Initial state
      expect(find.text('Count: 0'), findsOneWidget);
      // Check that the viewmodel is not paused initially
      final subWidgetState =
          tester.state<_SubWidgetState>(find.byType(SubWidget));
      expect(subWidgetState.isPaused, false);

      // Disable ticker
      await tester.tap(find.byKey(const Key('Toggle Ticker')));
      await tester.pump(const Duration(seconds: 1));

      // Check that the viewmodel is paused
      expect(subWidgetState.isPaused, true);

      // Try to increment, should not update
      await tester.tap(find.text('Increment'));
      await tester.pump();
      expect(find.text('Count: 0'), findsOneWidget);
      // Check that the viewmodel is not paused anymore
      print("subWidgetState.isPaused = ${subWidgetState.isPaused}");
      expect(subWidgetState.isPaused, true);

      // Enable ticker
      await tester.tap(find.byKey(const Key('Toggle Ticker')));
      await tester.pump();

      // Check that the viewmodel is not paused anymore
      print("subWidgetState.isPaused = ${subWidgetState.isPaused}");
      expect(subWidgetState.isPaused, false);

      // Try to increment, should update now
      await tester.tap(find.text('Increment'));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Count: ${subWidgetState.viewModel._count}'),
          findsOneWidget);
    });
  });
}
