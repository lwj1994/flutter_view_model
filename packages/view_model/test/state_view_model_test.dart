import 'package:flutter_test/flutter_test.dart';
import 'package:view_model/view_model.dart';

import 'test_widget.dart';

void main() {
  group('view_model state', () {
    setUpAll(() {
      ViewModel.initialize(config: ViewModelConfig(isLoggingEnabled: true));
    });

    test("should correctly trigger listeners on batch state updates", () {
      final owner = _createTestViewModelOwner();
      const total = 100;
      int listenStateCount = 0;

      owner.viewModel.listenState(onChanged: (p, s) {
        listenStateCount++;
        expect(s, listenStateCount.toString());
        expect(p, (listenStateCount - 1).toString());
      });

      int listenCallbackCount = 0;
      owner.viewModel.listen(onChanged: () {
        listenCallbackCount++;
      });

      for (int i = 1; i <= total; i++) {
        owner.viewModel.setState(i.toString());
      }

      // No need to wait - notifications are now synchronous
      expect(listenCallbackCount, total);
      expect(listenStateCount, total);
    });

    test("should correctly update state on notifyListeners", () {
      final owner = _createTestViewModelOwner();
      int completedCount = 0;

      owner.viewModel.listen(onChanged: () {
        expect(owner.viewModel.name, "a");
        completedCount += 1;
      });

      owner.viewModel.name = "a";
      owner.viewModel.notifyListeners();

      // No need to wait - notifications are now synchronous
      expect(completedCount, 1);
    });
  });

  group('state_view_model extras', () {
    test('listenState unsubscription works', () {
      final owner = _createTestViewModelOwner();
      final dispose = owner.viewModel.listenState(onChanged: (prev, curr) {});
      dispose();
    });

    test('notifyListeners after dispose is ignored', () {
      final owner = _createTestViewModelOwner();
      owner.notifyListenersAfterRecycle();
    });

    test('setState after dispose is ignored', () {
      final owner = _createTestViewModelOwner();
      owner.setStateAfterRecycle("1");
    });

    test('notifyListeners only notifies general listeners', () {
      final owner = _createTestViewModelOwner();
      final diffs = <(String?, String)>[];
      var selectedCount = 0;
      var generalCount = 0;

      owner.viewModel.listenState(onChanged: (previous, current) {
        diffs.add((previous, current));
      });
      owner.viewModel.listenStateSelect<String>(
        selector: (state) => state,
        onChanged: (_, __) => selectedCount++,
      );
      owner.viewModel.listen(onChanged: () => generalCount++);

      owner.viewModel.setState("1");
      expect(diffs, [("0", "1")]);
      expect(selectedCount, 1);
      expect(generalCount, 1);

      owner.viewModel.notifyListeners();

      expect(diffs, [("0", "1")]);
      expect(selectedCount, 1);
      expect(generalCount, 2);
    });

    test('selector equality is typed and defaults to ==', () {
      ViewModel.reset();
      final globalCalls = <(Object?, Object?)>[];
      ViewModel.initialize(
        config: ViewModelConfig(
          equals: (previous, current) {
            globalCalls.add((previous, current));
            return false;
          },
        ),
      );
      final owner = _createTestViewModelOwner();
      final changes = <(int?, int)>[];
      owner.viewModel.listenStateSelect<int>(
        selector: (state) => state.length,
        onChanged: (previous, current) {
          changes.add((previous, current));
        },
      );

      owner.viewModel.setState("1");
      expect(changes, isEmpty);
      expect(globalCalls, [("0", "1")]);

      owner.viewModel.setState("22");
      expect(changes, [(1, 2)]);
      expect(globalCalls, [("0", "1"), ("1", "22")]);

      ViewModel.reset();
      ViewModel.initialize(config: ViewModelConfig(isLoggingEnabled: true));
    });

    test('listenStateSelectWithEquals supports selected-value equality', () {
      final owner = _createTestViewModelOwner(initialState: "a");
      final changes = <(String?, String)>[];
      owner.viewModel.listenStateSelectWithEquals<String>(
        selector: (state) => state,
        equals: (previous, current) => previous.length == current.length,
        onChanged: (previous, current) {
          changes.add((previous, current));
        },
      );

      owner.viewModel.setState("b");
      owner.viewModel.setState("cc");

      expect(changes, [("b", "cc")]);
    });
  });

  group('notification timing consistency', () {
    test('StateViewModel notifies listeners synchronously', () {
      final owner = _createTestViewModelOwner();
      int callCount = 0;

      owner.viewModel.listen(onChanged: () {
        callCount++;
      });

      // Before setState, count should be 0
      expect(callCount, 0);

      // After setState, count should be immediately updated (synchronous)
      owner.viewModel.setState("1");
      expect(callCount, 1);

      owner.viewModel.setState("2");
      expect(callCount, 2);
    });

    test('StateViewModel state listeners are called synchronously', () {
      final owner = _createTestViewModelOwner();
      String? capturedPrevious;
      String? capturedCurrent;

      owner.viewModel.listenState(onChanged: (prev, curr) {
        capturedPrevious = prev;
        capturedCurrent = curr;
      });

      owner.viewModel.setState("1");

      // Should be immediately updated (synchronous)
      expect(capturedPrevious, "0");
      expect(capturedCurrent, "1");

      owner.viewModel.setState("2");
      expect(capturedPrevious, "1");
      expect(capturedCurrent, "2");
    });

    test('both state listeners and regular listeners are called synchronously',
        () {
      final owner = _createTestViewModelOwner();
      final callOrder = <String>[];

      owner.viewModel.listenState(onChanged: (prev, curr) {
        callOrder.add('state');
      });

      owner.viewModel.listen(onChanged: () {
        callOrder.add('regular');
      });

      owner.viewModel.setState("1");

      // Both should be called synchronously, state listeners first
      expect(callOrder, ['state', 'regular']);
    });
  });

  group('per-instance equals configuration', () {
    test('instance-level equals is used when provided', () {
      final owner = _createUserViewModelOwner(
        user: User(id: 1, name: "Alice"),
        // Only compare by ID
        equals: (prev, curr) => prev.id == curr.id,
      );

      int notifyCount = 0;
      owner.viewModel.listen(onChanged: () {
        notifyCount++;
      });

      // Same ID, different name - should NOT trigger notification
      owner.viewModel.setState(User(id: 1, name: "Alice Updated"));
      expect(notifyCount, 0);

      // Different ID - should trigger notification
      owner.viewModel.setState(User(id: 2, name: "Bob"));
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

      final owner = _createUserViewModelOwner(
        user: User(id: 1, name: "Alice"),
      );

      int notifyCount = 0;
      owner.viewModel.listen(onChanged: () {
        notifyCount++;
      });

      // Same ID - should NOT trigger (uses global equals)
      owner.viewModel.setState(User(id: 1, name: "Alice Updated"));
      expect(notifyCount, 0);

      // Different ID - should trigger
      owner.viewModel.setState(User(id: 2, name: "Bob"));
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

      final owner = _createUserViewModelOwner(
        user: User(id: 1, name: "Alice"),
        // Instance: compare by ID (should override global)
        equals: (prev, curr) => prev.id == curr.id,
      );

      int notifyCount = 0;
      owner.viewModel.listen(onChanged: () {
        notifyCount++;
      });

      // Same ID - instance equals says no update
      owner.viewModel.setState(User(id: 1, name: "Updated"));
      expect(notifyCount, 0);

      // Different ID - instance equals says update (overrides global)
      owner.viewModel.setState(User(id: 2, name: "Bob"));
      expect(notifyCount, 1);

      // Reset for other tests
      ViewModel.reset();
      ViewModel.initialize(config: ViewModelConfig(isLoggingEnabled: true));
    });

    test('defaults to identical when no equals is configured', () {
      ViewModel.reset();
      ViewModel.initialize(config: ViewModelConfig());

      final owner = _createUserViewModelOwner(
        user: User(id: 1, name: "Alice"),
      );

      int notifyCount = 0;
      owner.viewModel.listen(onChanged: () {
        notifyCount++;
      });

      // Different instance - should trigger (uses identical by default)
      owner.viewModel.setState(User(id: 1, name: "Alice"));
      expect(notifyCount, 1);

      // Reset for other tests
      ViewModel.reset();
      ViewModel.initialize(config: ViewModelConfig(isLoggingEnabled: true));
    });
  });
}

final _testViewModelSpec = ViewModelSpec.arg<TestViewModel, String>(
  builder: (state) => TestViewModel(state: state),
);

final _userViewModelSpec = ViewModelSpec.arg2<UserViewModel, User,
    bool Function(User previous, User current)?>(
  builder: (user, equals) => UserViewModel(user: user, equals: equals),
);

_TestViewModelOwner _createTestViewModelOwner({String initialState = "0"}) {
  final owner = _TestViewModelOwner(initialState);
  addTearDown(owner.dispose);
  return owner;
}

_UserViewModelOwner _createUserViewModelOwner({
  required User user,
  bool Function(User previous, User current)? equals,
}) {
  final owner = _UserViewModelOwner(user: user, equals: equals);
  addTearDown(owner.dispose);
  return owner;
}

class _TestViewModelOwner with ViewModelBinding {
  _TestViewModelOwner(this.initialState);

  final String initialState;

  TestViewModel get viewModel =>
      viewModelBinding.read(_testViewModelSpec(initialState));

  void notifyListenersAfterRecycle() {
    final disposedViewModel = viewModel;
    viewModelBinding.recycle(disposedViewModel);
    disposedViewModel.notifyListeners();
  }

  void setStateAfterRecycle(String state) {
    final disposedViewModel = viewModel;
    viewModelBinding.recycle(disposedViewModel);
    disposedViewModel.setState(state);
  }
}

class _UserViewModelOwner with ViewModelBinding {
  _UserViewModelOwner({required this.user, this.equals});

  final User user;
  final bool Function(User previous, User current)? equals;

  UserViewModel get viewModel =>
      viewModelBinding.read(_userViewModelSpec(user, equals));
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
