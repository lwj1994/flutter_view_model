import 'package:flutter_test/flutter_test.dart';
import 'package:view_model/src/get_instance/auto_dispose.dart';
import 'package:view_model/src/get_instance/manager.dart';
import 'package:view_model/src/get_instance/store.dart';
import 'package:view_model/src/view_model/config.dart';
import 'package:view_model/src/view_model/state_store.dart';
import 'package:view_model/src/view_model/vef.dart';
import 'package:view_model/src/view_model/view_model.dart';

import 'test_widget.dart';

class MockVef with Vef {}

void main() {
  group('AutoDisposeInstanceController', () {
    late AutoDisposeInstanceController controller;
    late MockVef mockRef;
    bool recreated = false;

    setUp(() {
      ViewModel.initialize(config: ViewModelConfig(isLoggingEnabled: true));
      mockRef = MockVef();
      recreated = false;
      controller = AutoDisposeInstanceController(
        onRecreate: () => recreated = true,
        vef: mockRef,
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
      expect(handle.bindedVefIds.any((id) => id == mockRef.id), isTrue);
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

      controller.getInstance<TestStatelessViewModel>(factory: factory);

      controller.dispose();

      final handle =
          instanceManager.getNotifier<TestStatelessViewModel>(factory: factory);
      // Should be removed from binders, and since it was the only one, it might be disposed/recycled.
      // However, getNotifier might recreate it if recycled?
      // If recycled, instanceManager might return a new handle with new instance if called again with factory?
      // Or if we check existing handle state?

      // If we check the handle retrieved BEFORE dispose:
      // It should have been disposed.

      expect(controller.instanceNotifiers, isEmpty);
    });

    test('recycle forces recreation', () {
      final factory = InstanceFactory<TestStatelessViewModel>(
        builder: () => TestStatelessViewModel(),
        arg: const InstanceArg(key: 'recycle_test'),
      );

      final vm1 =
          controller.getInstance<TestStatelessViewModel>(factory: factory);

      controller.recycle(vm1);

      // vm1 should be disposed
      expect(vm1.isDisposed, isTrue);

      // Getting again should create new instance
      final vm2 =
          controller.getInstance<TestStatelessViewModel>(factory: factory);
      expect(vm1, isNot(equals(vm2)));
    });

    test('recreate callback', () {
      final factory = InstanceFactory<TestStatelessViewModel>(
        builder: () => TestStatelessViewModel(),
        arg: const InstanceArg(key: 'recreate_callback_test'),
      );

      controller.getInstance<TestStatelessViewModel>(factory: factory);

      final handle =
          instanceManager.getNotifier<TestStatelessViewModel>(factory: factory);

      // Verify no recreate action (requires explicit recreate call)
      expect(handle.action, isNull);
    });

    test('recreate functionality - via InstanceManager', () {
      // Test the recreate functionality using the public InstanceManager API
      final factory = InstanceFactory<TestViewModel>(
        builder: () => TestViewModel(state: 'initial'),
        arg: const InstanceArg(key: 'recreate_test'),
      );

      // Create initial instance
      final vm1 = controller.getInstance<TestViewModel>(factory: factory);
      final initialHashCode = vm1.hashCode;

      // Get the handle to monitor action changes
      final handle = instanceManager.getNotifier<TestViewModel>(factory: factory);

      // Track action changes
      InstanceAction? capturedAction;
      handle.addListener(() {
        capturedAction = handle.action;
      });

      // Recreate the instance via InstanceManager
      final vm2 = instanceManager.recreate(vm1);

      // Verify new instance was created
      expect(vm2, isNotNull);
      expect(vm2.hashCode, isNot(equals(initialHashCode)),
          reason: 'Recreate should create a new instance');

      // Verify recreate action was triggered
      expect(capturedAction, equals(InstanceAction.recreate),
          reason: 'Recreate action should be set when instance is recreated');

      // Verify the handle now points to the new instance
      expect(handle.instance, equals(vm2));
    });

    test('recreate functionality - with custom builder', () {
      // Test recreate with a custom builder
      int createCount = 0;
      final factory = InstanceFactory<TestViewModel>(
        builder: () {
          createCount++;
          return TestViewModel(state: 'initial');
        },
        arg: const InstanceArg(key: 'recreate_custom_builder'),
      );

      // Create initial instance
      final vm1 = controller.getInstance<TestViewModel>(factory: factory);
      expect(createCount, equals(1));

      // Recreate with custom builder
      int customBuilderCalled = 0;
      final vm2 = instanceManager.recreate(
        vm1,
        builder: () {
          customBuilderCalled++;
          return TestViewModel(state: 'recreated');
        },
      );

      // Verify custom builder was used instead of original factory builder
      expect(customBuilderCalled, equals(1));
      expect(createCount, equals(1),
          reason: 'Original builder should not be called during recreate');

      // Verify new instance was created
      expect(vm2, isNotNull);
      expect(vm2, isNot(equals(vm1)));
    });

    test('recreate preserves watchers and bindings', () {
      // Test that recreate preserves watcher relationships
      final factory = InstanceFactory<TestViewModel>(
        builder: () => TestViewModel(state: 'with_watcher'),
        arg: const InstanceArg(
          key: 'recreate_preserve_watchers',
          vefId: 'test_watcher_1',
        ),
      );

      // Create instance with watcher
      final vm1 = controller.getInstance<TestViewModel>(factory: factory);
      final handle = instanceManager.getNotifier<TestViewModel>(factory: factory);

      // Verify initial watcher
      expect(handle.bindedVefIds, contains('test_watcher_1'));
      final initialWatcherCount = handle.bindedVefIds.length;

      // Recreate instance
      final vm2 = instanceManager.recreate(vm1);

      // Verify watchers are preserved after recreate
      expect(handle.bindedVefIds, contains('test_watcher_1'),
          reason: 'Watchers should be preserved after recreate');
      expect(handle.bindedVefIds.length, equals(initialWatcherCount),
          reason: 'Watcher count should remain the same');

      // Verify the handle points to new instance
      expect(handle.instance, equals(vm2));
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
      expect(handle.bindedVefIds.any((id) => id == mockRef.id), isTrue);

      controller.unbindInstance(vm);

      expect(handle.bindedVefIds.any((id) => id == mockRef.id), isFalse);
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

      test('listen: true attaches listeners and binds vef', () {
        const tag = 'listen_true_tag';
        final factory = InstanceFactory<TestStatelessViewModel>(
          builder: () => TestStatelessViewModel(),
          arg: const InstanceArg(key: 'vm_listen', tag: tag),
        );

        instanceManager.getNotifier<TestStatelessViewModel>(factory: factory);

        controller.getInstancesByTag<TestStatelessViewModel>(tag, listen: true);

        final handle = instanceManager.getNotifier<TestStatelessViewModel>(
            factory: factory);
        expect(handle.bindedVefIds.contains(mockRef.id), isTrue);
        expect(controller.instanceNotifiers.length, 1);
      });

      test('listen: false does not attach listeners or bind vef', () {
        const tag = 'listen_false_tag';
        final factory = InstanceFactory<TestStatelessViewModel>(
          builder: () => TestStatelessViewModel(),
          arg: const InstanceArg(key: 'vm_no_listen', tag: tag),
        );

        instanceManager.getNotifier<TestStatelessViewModel>(factory: factory);

        controller.getInstancesByTag<TestStatelessViewModel>(tag,
            listen: false);

        final handle = instanceManager.getNotifier<TestStatelessViewModel>(
            factory: factory);
        expect(handle.bindedVefIds.contains(mockRef.id), isFalse);
        expect(controller.instanceNotifiers, isEmpty);
      });
    });

    test('dispose cleans up refs from ViewModel', () {
      final factory = InstanceFactory<TestStatelessViewModel>(
        builder: () => TestStatelessViewModel(),
        arg: const InstanceArg(key: 'dispose_cleanup_test'),
      );

      final vm =
          controller.getInstance<TestStatelessViewModel>(factory: factory);

      // Manually add ref to simulate usage
      vm.refHandler.addRef(mockRef);
      expect(vm.refHandler.dependencyVefs.contains(mockRef), isTrue);

      controller.dispose();

      expect(vm.refHandler.dependencyVefs.contains(mockRef), isFalse);
    });
  });
}
