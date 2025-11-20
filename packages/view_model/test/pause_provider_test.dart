import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:view_model/src/view_model/pause_provider.dart';

void main() {
  group('TickModePauseProvider', () {
    late TickModePauseProvider provider;
    late ValueNotifier<bool> notifier;

    setUp(() {
      provider = TickModePauseProvider();
      notifier = ValueNotifier<bool>(true);
    });

    tearDown(() {
      provider.dispose();
      notifier.dispose();
    });

    test('should emit false (resume) when subscribed with true', () async {
      bool? isPaused;
      final subscription = provider.onPauseStateChanged.listen((event) {
        isPaused = event;
      });

      provider.subscribe(notifier);

      // Wait for stream to emit
      await Future.delayed(Duration.zero);

      expect(isPaused, isFalse);
      await subscription.cancel();
    });

    test('should emit true (pause) when subscribed with false', () async {
      notifier.value = false;
      bool? isPaused;
      final subscription = provider.onPauseStateChanged.listen((event) {
        isPaused = event;
      });

      provider.subscribe(notifier);

      // Wait for stream to emit
      await Future.delayed(Duration.zero);

      expect(isPaused, isTrue);
      await subscription.cancel();
    });

    test('should emit events when notifier value changes', () async {
      bool? isPaused;
      final subscription = provider.onPauseStateChanged.listen((event) {
        isPaused = event;
      });

      provider.subscribe(notifier);
      await Future.delayed(Duration.zero);
      expect(isPaused, isFalse);

      notifier.value = false;
      await Future.delayed(Duration.zero);
      expect(isPaused, isTrue);

      notifier.value = true;
      await Future.delayed(Duration.zero);
      expect(isPaused, isFalse);

      await subscription.cancel();
    });

    test('should handle resubscription', () async {
      final notifier2 = ValueNotifier<bool>(false);
      bool? isPaused;
      final subscription = provider.onPauseStateChanged.listen((event) {
        isPaused = event;
      });

      provider.subscribe(notifier);
      await Future.delayed(Duration.zero);
      expect(isPaused, isFalse);

      provider.subscribe(notifier2);
      await Future.delayed(Duration.zero);
      expect(isPaused, isTrue);

      notifier.value = false; // Should be ignored
      await Future.delayed(Duration.zero);
      expect(isPaused, isTrue);

      notifier2.value = true;
      await Future.delayed(Duration.zero);
      expect(isPaused, isFalse);

      await subscription.cancel();
      notifier2.dispose();
    });
  });
}
