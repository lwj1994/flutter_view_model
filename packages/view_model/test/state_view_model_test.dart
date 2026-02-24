import 'package:flutter_test/flutter_test.dart';
import 'package:view_model/view_model.dart';

import 'test_widget.dart';

void main() {
  group('view_model state', () {
    late TestViewModel viewModel;

    setUpAll(() {
      ViewModel.initialize(config: ViewModelConfig(isLoggingEnabled: true));
    });

    setUp(() {
      viewModel = TestViewModel(state: "0");
    });

    test("should correctly trigger listeners on batch state updates", () {
      const total = 100;
      int listenStateCount = 0;

      viewModel.listenState(onChanged: (p, s) {
        listenStateCount++;
        expect(s, listenStateCount.toString());
        expect(p, (listenStateCount - 1).toString());
      });

      int listenCallbackCount = 0;
      viewModel.listen(onChanged: () {
        listenCallbackCount++;
      });

      for (int i = 1; i <= total; i++) {
        viewModel.setState(i.toString());
      }

      // No need to wait - notifications are now synchronous
      expect(listenCallbackCount, total);
      expect(listenStateCount, total);
    });

    test("should correctly update state on notifyListeners", () {
      int completedCount = 0;

      viewModel.listen(onChanged: () {
        expect(viewModel.name, "a");
        completedCount += 1;
      });

      viewModel.name = "a";
      viewModel.notifyListeners();

      // No need to wait - notifications are now synchronous
      expect(completedCount, 1);
    });
  });

  group('state_view_model extras', () {
    test('listenState unsubscription works', () {
      final vm = TestViewModel(state: "0");
      final dispose = vm.listenState(onChanged: (prev, curr) {});
      dispose();
    });

    test('notifyListeners after dispose is ignored', () {
      final vm = TestViewModel(state: "0");
      vm.onDispose(const InstanceArg());
      vm.notifyListeners();
    });

    test('setState after dispose is ignored', () {
      final vm = TestViewModel(state: "0");
      vm.onDispose(const InstanceArg());
      vm.setState("1");
    });
  });

  group('notification timing consistency', () {
    test('StateViewModel notifies listeners synchronously', () {
      final vm = TestViewModel(state: "0");
      int callCount = 0;

      vm.listen(onChanged: () {
        callCount++;
      });

      // Before setState, count should be 0
      expect(callCount, 0);

      // After setState, count should be immediately updated (synchronous)
      vm.setState("1");
      expect(callCount, 1);

      vm.setState("2");
      expect(callCount, 2);
    });

    test('StateViewModel state listeners are called synchronously', () {
      final vm = TestViewModel(state: "0");
      String? capturedPrevious;
      String? capturedCurrent;

      vm.listenState(onChanged: (prev, curr) {
        capturedPrevious = prev;
        capturedCurrent = curr;
      });

      vm.setState("1");

      // Should be immediately updated (synchronous)
      expect(capturedPrevious, "0");
      expect(capturedCurrent, "1");

      vm.setState("2");
      expect(capturedPrevious, "1");
      expect(capturedCurrent, "2");
    });

    test('both state listeners and regular listeners are called synchronously',
        () {
      final vm = TestViewModel(state: "0");
      final callOrder = <String>[];

      vm.listenState(onChanged: (prev, curr) {
        callOrder.add('state');
      });

      vm.listen(onChanged: () {
        callOrder.add('regular');
      });

      vm.setState("1");

      // Both should be called synchronously, state listeners first
      expect(callOrder, ['state', 'regular']);
    });
  });

  group('per-instance equals configuration', () {
    test('instance-level equals is used when provided', () {
      final vm = UserViewModel(
        user: User(id: 1, name: "Alice"),
        // Only compare by ID
        equals: (prev, curr) => prev.id == curr.id,
      );

      int notifyCount = 0;
      vm.listen(onChanged: () {
        notifyCount++;
      });

      // Same ID, different name - should NOT trigger notification
      vm.setState(User(id: 1, name: "Alice Updated"));
      expect(notifyCount, 0);

      // Different ID - should trigger notification
      vm.setState(User(id: 2, name: "Bob"));
      expect(notifyCount, 1);
    });

    test('global config equals is used when instance-level not provided', () {
      // Set global config to compare by value
      ViewModel.reset();
      ViewModel.initialize(
        config: ViewModelConfig(
          equals: (prev, curr) {
            if (prev is User && curr is User) {
              return prev.id == curr.id;
            }
            return identical(prev, curr);
          },
        ),
      );

      final vm = UserViewModel(user: User(id: 1, name: "Alice"));

      int notifyCount = 0;
      vm.listen(onChanged: () {
        notifyCount++;
      });

      // Same ID - should NOT trigger (uses global equals)
      vm.setState(User(id: 1, name: "Alice Updated"));
      expect(notifyCount, 0);

      // Different ID - should trigger
      vm.setState(User(id: 2, name: "Bob"));
      expect(notifyCount, 1);

      // Reset for other tests
      ViewModel.reset();
      ViewModel.initialize(config: ViewModelConfig(isLoggingEnabled: true));
    });

    test('instance-level equals takes priority over global config', () {
      ViewModel.reset();
      ViewModel.initialize(
        config: ViewModelConfig(
          // Global: always return true (never update)
          equals: (prev, curr) => true,
        ),
      );

      final vm = UserViewModel(
        user: User(id: 1, name: "Alice"),
        // Instance: compare by ID (should override global)
        equals: (prev, curr) => prev.id == curr.id,
      );

      int notifyCount = 0;
      vm.listen(onChanged: () {
        notifyCount++;
      });

      // Same ID - instance equals says no update
      vm.setState(User(id: 1, name: "Updated"));
      expect(notifyCount, 0);

      // Different ID - instance equals says update (overrides global)
      vm.setState(User(id: 2, name: "Bob"));
      expect(notifyCount, 1);

      // Reset for other tests
      ViewModel.reset();
      ViewModel.initialize(config: ViewModelConfig(isLoggingEnabled: true));
    });

    test('defaults to identical when no equals is configured', () {
      ViewModel.reset();
      ViewModel.initialize(config: ViewModelConfig());

      final vm = UserViewModel(user: User(id: 1, name: "Alice"));

      int notifyCount = 0;
      vm.listen(onChanged: () {
        notifyCount++;
      });

      // Different instance - should trigger (uses identical by default)
      vm.setState(User(id: 1, name: "Alice"));
      expect(notifyCount, 1);

      // Reset for other tests
      ViewModel.reset();
      ViewModel.initialize(config: ViewModelConfig(isLoggingEnabled: true));
    });
  });
}

// Test model class for equals configuration tests
class User {
  final int id;
  final String name;

  User({required this.id, required this.name});
}

// Test ViewModel with custom state type
class UserViewModel extends StateViewModel<User> {
  UserViewModel({
    required User user,
    super.equals,
  }) : super(state: user);
}
