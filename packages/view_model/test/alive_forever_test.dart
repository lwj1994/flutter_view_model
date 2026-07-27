import 'package:flutter_test/flutter_test.dart';
import 'package:view_model/src/view_model/state_store.dart';
import 'package:view_model/view_model.dart';

class TestModel extends ViewModel {}

class AliveForeverFactory extends ViewModelSpec<TestModel> {
  AliveForeverFactory(
      {required super.builder, super.key, super.aliveForever = false});
}

class TestRef with ViewModelBinding {}

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

    test('aliveForever=true requires an explicit key on every binding', () {
      final ref = TestRef();
      addTearDown(ref.dispose);
      var buildCount = 0;
      final factory = AliveForeverFactory(
        builder: () {
          buildCount++;
          return TestModel();
        },
        aliveForever: true,
      );

      expect(
        () => ref.read(factory),
        throwsA(
          isA<ViewModelError>().having(
            (error) => error.message,
            'message',
            contains('must use an explicit key'),
          ),
        ),
      );
      expect(buildCount, 0);
    });

    test('Arg-based aliveForever rejects a computed null key', () {
      final ref = TestRef();
      addTearDown(ref.dispose);
      final provider = ViewModelSpec.arg<TestModel, int>(
        builder: (_) => TestModel(),
        key: (_) => null,
        aliveForever: (_) => true,
      );

      expect(
        () => ref.read(provider(1)),
        throwsA(
          isA<ViewModelError>().having(
            (error) => error.message,
            'message',
            contains('must use an explicit key'),
          ),
        ),
      );
    });

    test(
        'aliveForever=true: ViewModel does NOT dispose when watchers drop '
        'to zero', () async {
      final ref = TestRef();
      final factory = AliveForeverFactory(
        builder: () => TestModel(),
        key: 'forever_lifecycle',
        aliveForever: true,
      );

      // Create and Watch
      final vm = ref.watch(factory);
      final vmHash = vm.hashCode;

      // Drop the last watcher naturally.
      ref.dispose();
      await Future.delayed(const Duration(milliseconds: 20));

      // Should NOT be disposed, should exist in cache
      final cachedVm =
          ViewModel.readCached<TestModel>(key: 'forever_lifecycle');
      expect(cachedVm, isNotNull);
      expect(cachedVm.hashCode, vmHash);
      expect(identical(cachedVm, vm), isTrue);

      // Clean up is intentionally omitted: aliveForever keeps this cached.
    });

    test('Arg-based provider supports aliveForever', () {
      final ref = TestRef();
      final provider = ViewModelSpec.arg<TestModel, int>(
        builder: (arg) => TestModel(),
        key: (arg) => 'arg_forever_$arg',
        aliveForever: (_) => true,
      );

      final vm = ref.watch(provider(1));
      ref.dispose();

      final cached = ViewModel.readCached<TestModel>(key: 'arg_forever_1');
      expect(cached, isNotNull);
      expect(identical(cached, vm), isTrue);
    });

    test('recycle force-disposes aliveForever instances', () async {
      final ref = TestRef();
      final factory = AliveForeverFactory(
        builder: () => TestModel(),
        key: 'forever_recycle',
        aliveForever: true,
      );

      final vm = ref.watch(factory);
      ref.recycle(vm);
      await Future.delayed(const Duration(milliseconds: 20));

      expect(
        () => ViewModel.readCached<TestModel>(key: 'forever_recycle'),
        throwsA(isA<ViewModelError>()),
      );

      ref.dispose();
    });
  });
}
