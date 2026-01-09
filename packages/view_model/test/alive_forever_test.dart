import 'package:flutter_test/flutter_test.dart';
import 'package:view_model/src/view_model/state_store.dart';
import 'package:view_model/view_model.dart';

class TestModel extends ViewModel {}

class AliveForeverFactory extends ViewModelProvider<TestModel> {
  AliveForeverFactory(
      {required super.builder, super.key, super.aliveForever = false});
}

class TestRef with Vef {}

void main() {
  setUp(() {
    ViewModel.initialize(config: ViewModelConfig(isLoggingEnabled: true));
  });

  group('AliveForever Feature', () {
    test('Default behavior: ViewModel disposes when watchers drop to zero',
        () async {
      final ref = TestRef();
      final factory = AliveForeverFactory(
          builder: () => TestModel(), key: 'default_lifecycle');

      // Create and Watch
      final vm = ref.watch(factory);
      final vmHash = vm.hashCode;

      // Unwatch (recycle)
      ref.recycle(vm);
      await Future.delayed(const Duration(milliseconds: 20));

      // Should be disposed and removed from cache
      expect(
        () => ViewModel.readCached<TestModel>(key: 'default_lifecycle'),
        throwsA(isA<ViewModelError>()),
      );

      ref.dispose();
    });

    test(
        'aliveForever=true: ViewModel does NOT dispose when watchers drop to zero',
        () async {
      final ref = TestRef();
      final factory = AliveForeverFactory(
        builder: () => TestModel(),
        key: 'forever_lifecycle',
        aliveForever: true,
      );

      // Create and Watch
      final vm = ref.watch(factory);
      final vmHash = vm.hashCode;

      // Unwatch (recycle)
      ref.recycle(vm);
      await Future.delayed(const Duration(milliseconds: 20));

      // Should NOT be disposed, should exist in cache
      final cachedVm =
          ViewModel.readCached<TestModel>(key: 'forever_lifecycle');
      expect(cachedVm, isNotNull);
      expect(cachedVm.hashCode, vmHash);
      expect(identical(cachedVm, vm), isTrue);

      // Clean up manually for test isolation if needed,
      // but strictly speaking it lives forever until app restart or explicit manager clear.

      ref.dispose();
    });

    test('Arg-based provider supports aliveForever', () {
      final ref = TestRef();
      final provider = ViewModelProvider.arg<TestModel, int>(
        builder: (arg) => TestModel(),
        key: (arg) => 'arg_forever_$arg',
        aliveForever: (_) => true,
      );

      final vm = ref.watch(provider(1));
      ref.recycle(vm);

      final cached = ViewModel.readCached<TestModel>(key: 'arg_forever_1');
      expect(cached, isNotNull);
      expect(identical(cached, vm), isTrue);

      ref.dispose();
    });
  });
}
