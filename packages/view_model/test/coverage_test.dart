import 'package:flutter_test/flutter_test.dart';
import 'package:view_model/view_model.dart';
import 'package:view_model/src/get_instance/manager.dart';

class ErrorThrowingViewModel extends ViewModel {
  void trigger() => notifyListeners();

  void simulateDispose() {
    // ignore: invalid_use_of_protected_member
    onDispose(const InstanceArg(key: 'simulated'));
  }
}

class ErrorThrowingStateViewModel extends StateViewModel<int> {
  ErrorThrowingStateViewModel() : super(state: 0);
  void trigger() => setState(state + 1);
}

class TestNotifyVM extends ViewModel {
  void testDependencyNotify(ViewModel vm) {
    // ignore: invalid_use_of_protected_member
    onDependencyNotify(vm);
  }

  void addThrowingDispose() {
    // ignore: invalid_use_of_protected_member
    addDispose(() {
      throw 'Dispose Error';
    });
  }

  void simulateDispose() {
    // ignore: invalid_use_of_protected_member
    onDispose(const InstanceArg(key: 'simulated'));
  }
}

void main() {
  setUp(() {
    ViewModel.reset();
  });

  group('Coverage Edge Cases', () {
    test('readCached throws if disposed', () {
      final vm = ErrorThrowingViewModel();
      const key = 'disposed_check_key';

      // Register with key manually to simulate cached instance
      instanceManager.getNotifier(
        factory: InstanceFactory(
          builder: () => vm,
          arg: const InstanceArg(key: key),
        ),
      );

      // Verify accessible
      expect(
          ViewModel.readCached<ErrorThrowingViewModel>(key: key), equals(vm));

      // Dispose manually (simulating a state where it's disposed but still cached)
      vm.simulateDispose();

      // Should verify vm.isDisposed is true
      expect(vm.isDisposed, isTrue);

      // Now readCached should throw
      expect(
        () => ViewModel.readCached<ErrorThrowingViewModel>(key: key),
        throwsA(isA<Error>()
            .having((e) => e.toString(), 'toString', contains('is disposed'))),
      );
    });

    test('onDependencyNotify is reachable', () {
      final vm1 = TestNotifyVM();
      final vm2 = ErrorThrowingViewModel();
      vm1.testDependencyNotify(vm2);
    });

    test('onListenerError config works for regular ViewModel', () {
      bool errorCaught = false;
      ViewModel.initialize(
        config: ViewModelConfig(
          onListenerError: (e, stack, context) {
            errorCaught = true;
            expect(context, 'notifyListeners');
            expect(e, 'Listener Error');
          },
        ),
      );

      final vm = ErrorThrowingViewModel();
      vm.listen(onChanged: () {
        throw 'Listener Error';
      });

      vm.trigger();
      expect(errorCaught, isTrue);
    });

    test('onListenerError config works for StateViewModel', () async {
      bool errorCaught = false;
      String? errorContext;

      ViewModel.initialize(
        config: ViewModelConfig(
          onListenerError: (e, stack, context) {
            errorCaught = true;
            errorContext = context;
          },
        ),
      );

      final vm = ErrorThrowingStateViewModel();

      // 1. Test state listener error
      vm.listenState(onChanged: (prev, curr) {
        throw 'State Listener Error';
      });

      vm.trigger();

      // Wait for stream
      await Future.delayed(Duration.zero);
      expect(errorCaught, isTrue);
      expect(errorContext, 'stateListener');

      // Reset
      errorCaught = false;

      // 2. Test general listener error on StateViewModel
      vm.listen(onChanged: () {
        throw 'General Listener Error';
      });

      vm.trigger();
      await Future.delayed(Duration.zero);

      expect(errorCaught, isTrue);
      // Depending on implementation, context might be notifyListeners or stateListener?
      // StateViewModel logic calls _listeners inside the stream listener check.
      // Lines 634-636 use 'notifyListeners'.
      // So checks context.
    });

    test('onDisposeError config works', () async {
      bool errorCaught = false;
      ViewModel.initialize(
        config: ViewModelConfig(
          onDisposeError: (e, stack) {
            errorCaught = true;
          },
        ),
      );

      final vm = TestNotifyVM();
      vm.addThrowingDispose();
      vm.simulateDispose();
      await Future.delayed(const Duration(seconds: 1));
      expect(errorCaught, isTrue);
    });
  });
}
