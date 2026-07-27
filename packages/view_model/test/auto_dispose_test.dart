import 'package:flutter_test/flutter_test.dart';
import 'package:view_model/src/get_instance/auto_dispose.dart';
import 'package:view_model/src/get_instance/manager.dart';
import 'package:view_model/src/get_instance/store.dart';
import 'package:view_model/src/view_model/config.dart';
import 'package:view_model/src/view_model/state_store.dart';
import 'package:view_model/src/view_model/view_model_binding.dart';
import 'package:view_model/src/view_model/view_model.dart';

import 'test_widget.dart';

class MockViewModelBinding with ViewModelBinding {
  @override
  String get id => 'mock_binding';
}

class MutableHashBinding with ViewModelBinding {
  int salt = 1;

  @override
  int get hashCode => salt;

  @override
  bool operator ==(Object other) => identical(this, other);
}

void main() {
  group('AutoDisposeInstanceController', () {
    late AutoDisposeInstanceController controller;
    late MockViewModelBinding mockRef;

    setUp(() {
      ViewModel.initialize(config: ViewModelConfig(isLoggingEnabled: true));
      mockRef = MockViewModelBinding();
      controller = AutoDisposeInstanceController(
        onHandleDisposing: () {},
        viewModelBinding: mockRef,
      );
    });

    test('getInstance adds binder and returns instance', () {
      final factory = InstanceFactory<TestStatelessViewModel>(
        builder: () => TestStatelessViewModel(),
        arg: const InstanceArg(key: 'auto_dispose_test'),
      );

      final vm =
          controller.getInstance<TestStatelessViewModel>(factory: factory);
      expect(vm, isNotNull);
      expect(controller.instanceNotifiers.length, 1);

      final handle =
          instanceManager.getNotifier<TestStatelessViewModel>(factory: factory);
      expect(handle.bindingIds.any((id) => id == mockRef.id), isTrue);
    });

    test('getInstance with dynamic throws error', () {
      expect(
        () => controller.getInstance<dynamic>(),
        throwsA(isA<ViewModelError>()),
      );
    });

    test('dispose removes binder', () {
      final factory = InstanceFactory<TestStatelessViewModel>(
        builder: () => TestStatelessViewModel(),
        arg: const InstanceArg(key: 'dispose_test'),
      );

      final viewModel =
          controller.getInstance<TestStatelessViewModel>(factory: factory);

      controller.dispose();

      expect(viewModel.isDisposed, isTrue);
      expect(controller.instanceNotifiers, isEmpty);
    });

    test('external recycle invokes the handle-disposing callback once', () {
      var disposalNotifications = 0;
      bool? wasDisposedDuringCallback;
      late TestStatelessViewModel vm;
      final observingController = AutoDisposeInstanceController(
        onHandleDisposing: () {
          disposalNotifications++;
          wasDisposedDuringCallback = vm.isDisposed;
        },
        viewModelBinding: mockRef,
      );
      final factory = InstanceFactory<TestStatelessViewModel>(
        builder: TestStatelessViewModel.new,
        arg: const InstanceArg(key: 'handle_disposed_callback_test'),
      );
      vm = observingController.getInstance<TestStatelessViewModel>(
        factory: factory,
      );

      instanceManager.recycle(vm);

      expect(disposalNotifications, 1);
      expect(wasDisposedDuringCallback, isFalse);
      expect(vm.isDisposed, isTrue);
      expect(observingController.instanceNotifiers, isEmpty);
      observingController.dispose();
    });

    test('performForAllInstances', () {
      final factory = InstanceFactory<TestStatelessViewModel>(
        builder: () => TestStatelessViewModel(),
        arg: const InstanceArg(key: 'perform_test'),
      );

      controller.getInstance<TestStatelessViewModel>(factory: factory);

      int count = 0;
      controller.performForAllInstances((vm) {
        count++;
        expect(vm, isA<TestStatelessViewModel>());
      });

      expect(count, 1);
    });

    test('performForAllInstances reports action errors', () {
      final previousConfig = ViewModel.config;
      final actionError = StateError('perform action failed');
      Object? reportedError;
      StackTrace? reportedStack;
      ErrorType? reportedType;

      ViewModel.reset();
      ViewModel.initialize(
        config: ViewModelConfig(
          onError: (error, stack, type) {
            reportedError = error;
            reportedStack = stack;
            reportedType = type;
          },
        ),
      );
      addTearDown(() {
        controller.dispose();
        mockRef.dispose();
        ViewModel.reset();
        ViewModel.initialize(config: previousConfig);
      });

      final factory = InstanceFactory<TestStatelessViewModel>(
        builder: () => TestStatelessViewModel(),
        arg: const InstanceArg(key: 'perform_error_test'),
      );
      controller.getInstance<TestStatelessViewModel>(factory: factory);

      expect(
        () => controller.performForAllInstances((_) => throw actionError),
        returnsNormally,
      );
      expect(reportedError, same(actionError));
      expect(reportedStack, isNotNull);
      expect(reportedType, ErrorType.lifecycle);
    });

    test('unbindInstance', () {
      final factory = InstanceFactory<TestStatelessViewModel>(
        builder: () => TestStatelessViewModel(),
        arg: const InstanceArg(key: 'unbind_test'),
      );

      final vm =
          controller.getInstance<TestStatelessViewModel>(factory: factory);
      final handle =
          instanceManager.getNotifier<TestStatelessViewModel>(factory: factory);
      assert(vm == handle.instance);
      expect(handle.bindingIds.any((id) => id == mockRef.id), isTrue);

      controller.unbindInstance(vm);

      expect(handle.bindingIds.any((id) => id == mockRef.id), isFalse);
    });
    group('getInstancesByTag', () {
      test('returns instances with matching tag', () {
        const tag = 'test_tag';
        final factory1 = InstanceFactory<TestStatelessViewModel>(
          builder: () => TestStatelessViewModel(),
          arg: const InstanceArg(key: 'vm1', tag: tag),
        );
        final factory2 = InstanceFactory<TestStatelessViewModel>(
          builder: () => TestStatelessViewModel(),
          arg: const InstanceArg(key: 'vm2', tag: tag),
        );

        // Create instances first
        instanceManager.getNotifier<TestStatelessViewModel>(factory: factory1);
        instanceManager.getNotifier<TestStatelessViewModel>(factory: factory2);

        final instances =
            controller.getInstancesByTag<TestStatelessViewModel>(tag);

        expect(instances.length, 2);
        expect(controller.instanceNotifiers.length, 2);
      });

      test('binds viewModelBinding and tracks notifier for cleanup', () {
        const tag = 'bind_tag';
        final factory = InstanceFactory<TestStatelessViewModel>(
          builder: () => TestStatelessViewModel(),
          arg: const InstanceArg(key: 'vm_bind', tag: tag),
        );

        instanceManager.getNotifier<TestStatelessViewModel>(factory: factory);

        controller.getInstancesByTag<TestStatelessViewModel>(tag);

        final handle = instanceManager.getNotifier<TestStatelessViewModel>(
            factory: factory);
        expect(handle.bindingIds.contains(mockRef.id), isTrue);
        expect(controller.instanceNotifiers.length, 1);
      });
    });

    test('dispose cleans up refs from ViewModel', () {
      final factory = InstanceFactory<TestStatelessViewModel>(
        builder: () => TestStatelessViewModel(),
        arg: const InstanceArg(key: 'dispose_cleanup_test'),
      );

      final vm =
          controller.getInstance<TestStatelessViewModel>(factory: factory);

      expect(vm.refHandler.dependencyBindings.contains(mockRef), isTrue);

      controller.dispose();

      expect(vm.refHandler.dependencyBindings.contains(mockRef), isFalse);
    });

    test('dispose still unbinds when host hashCode changes', () {
      final flakyBinding = MutableHashBinding();
      final flakyController = AutoDisposeInstanceController(
        onHandleDisposing: () {},
        viewModelBinding: flakyBinding,
      );
      final factory = InstanceFactory<TestStatelessViewModel>(
        builder: () => TestStatelessViewModel(),
        arg: const InstanceArg(key: 'stable_binding_id_test'),
      );

      final vm =
          flakyController.getInstance<TestStatelessViewModel>(factory: factory);

      flakyBinding.salt = 99;
      flakyController.dispose();

      expect(vm.isDisposed, isTrue);
    });
  });
}
