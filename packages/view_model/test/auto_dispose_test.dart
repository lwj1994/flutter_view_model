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

    test('dispose removes binder', () async {
      final factory = InstanceFactory<TestStatelessViewModel>(
        builder: () => TestStatelessViewModel(),
        arg: const InstanceArg(key: 'dispose_test'),
      );

      controller.getInstance<TestStatelessViewModel>(factory: factory);

      await controller.dispose();

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

      // Recreate action simulation note
      // Action changes are internal to store.dart and trigger `notifyListeners`.
      // `recycle` sets action to `dispose`. `InstanceAction.recreate` occurs
      // when a new instance replaces an old one within the same handle.
      // There is no public API to force `recreate` directly from a test.
      // See `src/get_instance/store.dart` for action transitions.
      // TODO: add a minimal scenario that naturally leads to `recreate`.
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
  });
}
