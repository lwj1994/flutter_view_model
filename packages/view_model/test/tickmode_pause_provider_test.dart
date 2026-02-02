import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
  final WidgetBuilder child;

  const TestTickerWidget({super.key, required this.child});

  @override
  State<TestTickerWidget> createState() => _TestTickerWidgetState();
}

class _TestTickerWidgetState extends State<TestTickerWidget>
    with ViewModelStateMixin {
  bool tickerEnabled = true;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Column(
        children: [
          TextButton(
            key: const Key('Toggle Ticker'),
            onPressed: () {
              print(
                  "_TestTickerWidgetState onPressed tickerEnabled = ${!tickerEnabled}");
              setState(() => tickerEnabled = !tickerEnabled);
            },
            child: const Text('Toggle Ticker'),
          ),
          TickerMode(enabled: tickerEnabled, child: widget.child.call(context)),
        ],
      ),
    );
  }
}

class SubStatefulWidget extends StatefulWidget {
  const SubStatefulWidget({super.key});

  @override
  State<SubStatefulWidget> createState() => _SubStatefulWidgetState();
}

class _SubStatefulWidgetState extends State<SubStatefulWidget>
    with ViewModelStateMixin {
  late final TestViewModel viewModel;

  @override
  void initState() {
    super.initState();
    final notifier = TickerMode.getNotifier(context);
    notifier.addListener(() {
      print("_SubWidgetState TickerMode = ${notifier.value}");
    });
    viewModel =
        viewModelBinding.watch(ViewModelSpec(builder: () => TestViewModel()));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('Count: ${viewModel.count}'),
        TextButton(
          onPressed: () {
            viewModel.increment();
          },
          child: const Text('Increment'),
        ),
      ],
    );
  }
}

// Widget for StatelessWidget test
class StatelessTestWidget extends StatelessWidget with ViewModelStatelessMixin {
  StatelessTestWidget({super.key});

  final _tickerModeProvider = TickerModePauseProvider();

  @override
  Widget build(BuildContext context) {
    print("StatelessTestWidget TickerMode = ${TickerMode.of(context)}");
    _tickerModeProvider.subscribe(TickerMode.getNotifier(context));
    viewModelBinding.addPauseProvider(_tickerModeProvider);
    final viewModel = viewModelBinding
        .watch<TestViewModel>(ViewModelSpec(builder: () => TestViewModel()));
    return Column(
      children: [
        Text('Count: ${viewModel.count}'),
        ElevatedButton(
          onPressed: () => viewModel.increment(),
          child: const Text('Increment'),
        ),
      ],
    );
  }
}

void main() {
  group('Pause Providers', () {
    setUp(() {
      ViewModel.initialize(config: ViewModelConfig(isLoggingEnabled: true));
    });

    testWidgets('ViewModel does not update when TickerMode is disabled',
        (tester) async {
      await tester.pumpWidget(TestTickerWidget(
        child: (c) {
          return const SubStatefulWidget();
        },
      ));

      // Initial state
      expect(find.text('Count: 0'), findsOneWidget);
      // Check that the viewmodel is not paused initially
      final subWidgetState =
          tester.state<_SubStatefulWidgetState>(find.byType(SubStatefulWidget));
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

    testWidgets('SubStatelessWidget pause', (tester) async {
      final StatelessTestWidget w = StatelessTestWidget(
        key: const ValueKey("test"),
      );
      await tester.pumpWidget(TestTickerWidget(child: (c) {
        return w;
      }), duration: const Duration(seconds: 1));
      // Initial state
      expect(find.text('Count: 0'), findsOneWidget);
      // Check that the viewmodel is not paused initially
      expect(w.isPaused, false);

      // Disable ticker
      await tester.tap(find.byKey(const Key('Toggle Ticker')));
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(w.isPaused, true);
      await tester.tap(find.text('Increment'));
      await tester.pump(const Duration(seconds: 1));
      expect(ViewModel.readCached<TestViewModel>()._count, 1);
      expect(find.text('Count: 0'), findsOneWidget);

      await tester.tap(find.byKey(const Key('Toggle Ticker')));
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(find.text('Count: 1'), findsOneWidget);

      await tester.tap(find.text('Increment'));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Count: 2'), findsOneWidget);

      // print("widget.isPaused = ${widget.isPaused}");
    });
  });
}
