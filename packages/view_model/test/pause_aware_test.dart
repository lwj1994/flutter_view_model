import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:view_model/src/view_model/pause_aware.dart';
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
  group('PageRouteAwareController Unit Tests', () {
    late ViewModelManualPauseProvider provider1;
    late ViewModelManualPauseProvider provider2;
    late ViewModelManualPauseProvider provider3;
    late PauseAwareController controller;
    int pauseCount = 0;
    int resumeCount = 0;

    setUp(() {
      provider1 = ViewModelManualPauseProvider();
      provider2 = ViewModelManualPauseProvider();
      provider3 = ViewModelManualPauseProvider();
      pauseCount = 0;
      resumeCount = 0;
      controller = PauseAwareController(
        providers: [provider1, provider2, provider3],
        onWidgetPause: () => pauseCount++,
        onWidgetResume: () => resumeCount++,
        binderName: 'test',
      );
    });

    tearDown(() {
      controller.dispose();
    });

    test('onPause is called when a provider signals pause', () async {
      provider1.pause();
      await Future.microtask(() {});
      expect(pauseCount, 1);
      expect(resumeCount, 0);
    });

    test('onResume is called when all providers signal resume', () async {
      provider1.pause();
      await Future.microtask(() {});
      expect(pauseCount, 1);

      provider1.resume();
      await Future.microtask(() {});
      expect(resumeCount, 1);
    });

    test('onPause is not called again if already paused', () async {
      provider1.pause();
      await Future.microtask(() {});
      provider2.pause();
      await Future.microtask(() {});
      expect(pauseCount, 1);
    });

    test('onResume is not called until all providers have resumed', () async {
      provider1.pause();
      await Future.microtask(() {});
      provider2.pause();
      await Future.microtask(() {});
      expect(pauseCount, 1);

      provider1.resume();
      await Future.microtask(() {});
      expect(resumeCount, 0); // Still paused by provider2

      provider2.resume();
      await Future.microtask(() {});
      expect(resumeCount, 1); // Now all have resumed
    });

    test(
      'handles chaotic, interleaved pause and resume signals from multiple providers',
      () async {
        // 1. First provider pauses, triggers onPause.
        provider1.pause();
        await Future.microtask(() {});
        expect(pauseCount, 1,
            reason: 'onPause should be called on the first pause signal');
        expect(resumeCount, 0);

        // 2. Second provider pauses, onPause should not be called again.
        provider2.pause();
        await Future.microtask(() {});
        expect(pauseCount, 1,
            reason: 'onPause should not be called again when already paused');

        // 3. First provider resumes, but second is still paused, so no onResume.
        provider1.resume();
        await Future.microtask(() {});
        expect(resumeCount, 0,
            reason:
                'onResume should not be called while other providers are still paused');

        // 4. Third provider pauses, onPause should not be called again.
        provider3.pause();
        await Future.microtask(() {});
        expect(pauseCount, 1);

        // 5. Second provider resumes, but third is still paused.
        provider2.resume();
        await Future.microtask(() {});
        expect(resumeCount, 0,
            reason:
                'onResume should not be called while other providers are still paused');

        // 6. First provider pauses again, no change.
        provider1.pause();
        await Future.microtask(() {});
        expect(pauseCount, 1);

        // 7. Third provider resumes, but first is still paused.
        provider3.resume();
        await Future.microtask(() {});
        expect(resumeCount, 0,
            reason:
                'onResume should not be called while other providers are still paused');

        // 8. First provider resumes. Now all are resumed, onResume is called.
        provider1.resume();
        await Future.microtask(() {});
        expect(resumeCount, 1,
            reason:
                'onResume should be called once all providers have resumed');

        // 9. Calling resume again on a resumed provider has no effect.
        provider1.resume();
        await Future.microtask(() {});
        expect(resumeCount, 1,
            reason: 'onResume should not be called again if already resumed');
      },
    );
  });

  group('PageRouteAwareController Widget Integration Tests', () {
    testWidgets(
      'Widget does not rebuild when paused by route change and rebuilds on resume',
      (WidgetTester tester) async {
        final routeObserver = ViewModel.routeObserver;
        await tester.pumpWidget(MaterialApp(
          navigatorObservers: [routeObserver],
          home: const AwareWidget(),
        ));

        final awareWidgetFinder = find.byType(AwareWidget);
        final state = tester.state(awareWidgetFinder) as _AwareWidgetState;
        final viewModel = state.viewModel;

        expect(find.text('Counter: 0'), findsOneWidget);

        Navigator.of(tester.element(awareWidgetFinder)).push(
          MaterialPageRoute(
            builder: (_) => const Scaffold(body: Text('Second Page')),
          ),
        );
        await tester.pumpAndSettle(const Duration(milliseconds: 1000));

        viewModel.increment();
        expect(viewModel.counter, 1);
        await tester.pump(const Duration(seconds: 1));
        Navigator.of(tester.element(find.byType(Scaffold))).pop();
        await tester.pumpAndSettle(const Duration(milliseconds: 1000));

        expect(find.text('Counter: 1'), findsOneWidget);
      },
    );

    testWidgets(
      'Widget pauses on app background and resumes on foreground',
      (WidgetTester tester) async {
        final routeObserver = ViewModel.routeObserver;
        await tester.pumpWidget(MaterialApp(
          navigatorObservers: [routeObserver],
          home: const AwareWidget(),
        ));

        final awareWidgetFinder = find.byType(AwareWidget);
        final state = tester.state(awareWidgetFinder) as _AwareWidgetState;
        final viewModel = state.viewModel;

        expect(find.text('Counter: 0'), findsOneWidget);

        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await tester.pump();

        viewModel.increment();
        expect(viewModel.counter, 1);
        expect(find.text('Counter: 0'), findsOneWidget);

        tester.binding
            .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await tester.pumpAndSettle();

        expect(find.text('Counter: 1'), findsOneWidget);
      },
    );
  });
}
