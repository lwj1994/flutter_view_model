import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:view_model/src/view_model/app_lifecycle_observer.dart';

void main() {
  group('AppLifecycleObserver', () {
    testWidgets('currentState returns lifecycle state', (tester) async {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      expect(AppLifecycleObserver().currentState, AppLifecycleState.resumed);
    });

    test('singleton instance', () {
      final observer1 = AppLifecycleObserver();
      final observer2 = AppLifecycleObserver();
      expect(observer1, same(observer2));
    });

    test('stream emits events', () async {
      final observer = AppLifecycleObserver();
      final events = <AppLifecycleState>[];
      final sub = observer.stream.listen(events.add);

      // Manually trigger didChangeAppLifecycleState
      observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
      observer.didChangeAppLifecycleState(AppLifecycleState.paused);

      await Future.delayed(Duration.zero);
      expect(events, [AppLifecycleState.resumed, AppLifecycleState.paused]);

      await sub.cancel();
    });

    test('dispose closes stream', () async {
      // Note: AppLifecycleObserver is a singleton. Disposing it might affect other tests
      // if not careful. Since this is the last test, it should be fine for this file.
      // In a real app, it shouldn't be disposed unless the app is terminating or in specific isolated scenarios.
      final observer = AppLifecycleObserver();
      observer.dispose();

      // Verifying dispose logic
      // Since _streamController is private, we can't check isClosed directly easily without reflection or observing behavior.
      // But we can try to listen and see if it's done, or try to add event and expect error.

      expect(
          () => observer.didChangeAppLifecycleState(AppLifecycleState.resumed),
          throwsStateError);
    });
  });
}
