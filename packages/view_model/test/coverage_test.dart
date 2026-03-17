import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:view_model/src/get_instance/manager.dart';
import 'package:view_model/src/view_model/pause_aware.dart';
import 'package:view_model/view_model.dart';

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

class _ThrowingLifecycle extends ViewModelLifecycle {
  @override
  void onCreate(ViewModel viewModel, InstanceArg arg) {
    throw 'Lifecycle onCreate Error';
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

      // Dispose manually (simulating a state where it is disposed but still
      // cached).
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

    test('onError config works for regular ViewModel listener', () {
      bool errorCaught = false;
      ViewModel.initialize(
        config: ViewModelConfig(
          onError: (e, stack, type) {
            errorCaught = true;
            expect(type, ErrorType.listener);
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

    test('onError config works for StateViewModel listener', () async {
      bool errorCaught = false;
      ErrorType? errorType;

      ViewModel.initialize(
        config: ViewModelConfig(
          onError: (e, stack, type) {
            errorCaught = true;
            errorType = type;
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
      expect(errorType, ErrorType.listener);

      // Reset
      errorCaught = false;

      // 2. Test general listener error on StateViewModel
      vm.listen(onChanged: () {
        throw 'General Listener Error';
      });

      vm.trigger();
      await Future.delayed(Duration.zero);

      expect(errorCaught, isTrue);
    });

    test('onError config works for dispose', () async {
      bool errorCaught = false;
      ViewModel.initialize(
        config: ViewModelConfig(
          onError: (e, stack, type) {
            errorCaught = true;
            expect(type, ErrorType.dispose);
          },
        ),
      );

      final vm = TestNotifyVM();
      vm.addThrowingDispose();
      vm.simulateDispose();
      await Future.delayed(const Duration(seconds: 1));
      expect(errorCaught, isTrue);
    });

    test('onError config works for ErrorType.lifecycle', () {
      bool errorCaught = false;
      ViewModel.initialize(
        config: ViewModelConfig(
          onError: (e, stack, type) {
            errorCaught = true;
            expect(type, ErrorType.lifecycle);
            expect(e, 'Lifecycle onCreate Error');
          },
        ),
        lifecycles: [_ThrowingLifecycle()],
      );

      instanceManager.getNotifier(
        factory: InstanceFactory(
          builder: () => ErrorThrowingViewModel(),
          arg: const InstanceArg(key: 'lifecycle_test'),
        ),
      );
      expect(errorCaught, isTrue);
    });

    test('onError config works for ErrorType.pauseResume', () async {
      bool errorCaught = false;
      ViewModel.initialize(
        config: ViewModelConfig(
          onError: (e, stack, type) {
            errorCaught = true;
            expect(type, ErrorType.pauseResume);
          },
        ),
      );

      final provider = ViewModelBindingPauseProvider();
      final controller = PauseAwareController(
        onWidgetPause: () {
          throw 'Pause Error';
        },
        onWidgetResume: () {},
        providers: [provider],
      );

      provider.pause();
      await Future.delayed(Duration.zero);
      expect(errorCaught, isTrue);
      controller.dispose();
      provider.dispose();
    });

    test(
        'reportViewModelError secondary catch '
        'when onError throws', () {
      final logs = <String>[];
      final originalDebugPrint = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) logs.add(message);
      };

      ViewModel.initialize(
        config: ViewModelConfig(
          onError: (e, stack, type) {
            throw 'Handler Error';
          },
        ),
      );

      final vm = ErrorThrowingViewModel();
      vm.listen(onChanged: () {
        throw 'Original Error';
      });

      // Should NOT throw — secondary catch handles it
      vm.trigger();

      expect(
        logs.any((l) => l.contains('onError callback threw')),
        isTrue,
      );
      expect(
        logs.any((l) => l.contains('Handler Error')),
        isTrue,
      );
      expect(
        logs.any((l) => l.contains('Original Error')),
        isTrue,
      );

      debugPrint = originalDebugPrint;
    });

    test(
        'error reporting works '
        'even when isLoggingEnabled is false', () {
      final logs = <String>[];
      final originalDebugPrint = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) logs.add(message);
      };

      ViewModel.initialize(
        config: ViewModelConfig(isLoggingEnabled: false),
      );

      final vm = ErrorThrowingViewModel();
      vm.listen(onChanged: () {
        throw 'Silent Error';
      });

      vm.trigger();

      expect(
        logs.any((l) => l.contains('Silent Error')),
        isTrue,
      );

      debugPrint = originalDebugPrint;
    });
  });
}
