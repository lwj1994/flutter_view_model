import 'package:flutter_test/flutter_test.dart';
import 'package:view_model/src/get_instance/auto_dispose.dart';
import 'package:view_model/src/get_instance/manager.dart';
import 'package:view_model/view_model.dart';
// import 'common.dart';

class TestViewModel extends ViewModel {
  int value = 0;
}

class TestVef with Vef {}

void main() {
  group('InstanceArg Coverage', () {
    test('toMap and fromMap', () {
      const arg = InstanceArg(
        key: 'test_key',
        tag: 'test_tag',
        vefId: 'test_vef',
        aliveForever: true,
      );

      final map = arg.toMap();
      expect(map['key'], 'test_key');
      expect(map['tag'], 'test_tag');
      expect(map['vefId'], 'test_vef');
      expect(map['aliveForever'], true);

      final newArg = InstanceArg.fromMap(map);
      expect(newArg, equals(arg));
      expect(newArg.hashCode, equals(arg.hashCode));
    });

    test('toString', () {
      const arg = InstanceArg(key: 'k', tag: 't', vefId: 'v');
      expect(arg.toString(), contains('key: k'));
    });

    test('equality', () {
      const arg1 = InstanceArg(key: 'a');
      const arg2 = InstanceArg(key: 'a');
      const arg3 = InstanceArg(key: 'b');

      expect(arg1, equals(arg2));
      expect(arg1, isNot(equals(arg3)));
      expect(arg1, isNot(equals('string')));
    });

    test('copyWith', () {
      const arg = InstanceArg(key: 'a', tag: 'b');
      final copy = arg.copyWith(key: 'c');
      expect(copy.key, 'c');
      expect(copy.tag, 'b');
    });
  });

  group('AutoDisposeInstanceController Coverage', () {
    test('unbindInstance', () {
      final vef = TestVef();
      final controller = AutoDisposeInstanceController(
        onRecreate: () {},
        vef: vef,
      );

      final factory =
          InstanceFactory<TestViewModel>(builder: () => TestViewModel());
      final vm = controller.getInstance(factory: factory);

      // Verify instance is tracked
      expect(controller.instanceNotifiers.length, 1);

      // Unbind
      controller.unbindInstance(vm);

      controller.dispose();
    });

    test('performForAllInstances', () {
      final vef = TestVef();
      final controller = AutoDisposeInstanceController(
        onRecreate: () {},
        vef: vef,
      );

      final factory =
          InstanceFactory<TestViewModel>(builder: () => TestViewModel());
      final vm = controller.getInstance(factory: factory);

      int count = 0;
      controller.performForAllInstances((v) {
        if (v is TestViewModel) {
          count++;
          v.value = 10;
        }
      });

      expect(count, 1);
      expect(vm.value, 10);

      controller.dispose();
    });

    test('getInstancesByTag with listen=false', () {
      final vef = TestVef();
      final controller = AutoDisposeInstanceController(
        onRecreate: () {},
        vef: vef,
      );

      // Create an instance in the store with a tag
      final sharedKey = Object();
      final factory = InstanceFactory<TestViewModel>(
        builder: () => TestViewModel(),
        arg: InstanceArg(tag: 'tag1', key: sharedKey),
      );

      // Manually create via manager so it's in the store
      final notifier = instanceManager.getNotifier(factory: factory);

      // Now get by tag via controller
      final list =
          controller.getInstancesByTag<TestViewModel>('tag1', listen: false);
      expect(list, contains(notifier.instance));
      expect(controller.instanceNotifiers.contains(notifier), isFalse);

      controller.dispose();
    });

    test('recycle', () {
      final vef = TestVef();
      final controller = AutoDisposeInstanceController(
        onRecreate: () {},
        vef: vef,
      );

      final factory =
          InstanceFactory<TestViewModel>(builder: () => TestViewModel());
      final vm = controller.getInstance(factory: factory);

      expect(controller.instanceNotifiers.length, 1);

      controller.recycle(vm);

      expect(
          controller.instanceNotifiers.any((n) => n.instance == vm), isFalse);

      controller.dispose();
    });
  });
}
