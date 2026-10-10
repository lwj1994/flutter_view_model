import 'package:flutter_test/flutter_test.dart';
import 'package:view_model/src/view_model/state_store.dart';
import 'package:view_model/view_model.dart';

class _CounterVM with ViewModel {
  int value = 0;

  void bump() => update(() => value++);
}

class _Parent with ViewModel {
  _CounterVM get child => viewModelBinding.read(_childSpec);
}

final _childSpec = ViewModelSpec<_CounterVM>(builder: _CounterVM.new);

class _CountingBinding with ViewModelBinding {
  int updates = 0;

  @override
  void onUpdate() {
    super.onUpdate();
    updates++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(ViewModel.reset);

  group('spec resolution cache hit', () {
    test('repeated resolution reuses the instance and builder runs once', () {
      var builds = 0;
      final spec = ViewModelSpec<_CounterVM>(builder: () {
        builds++;
        return _CounterVM();
      });
      final binding = _CountingBinding();
      addTearDown(binding.dispose);

      final first = binding.read(spec);
      for (var i = 0; i < 5; i++) {
        expect(binding.read(spec), same(first));
        expect(binding.watch(spec), same(first));
      }
      expect(builds, 1);
    });

    test('watch after a read hit still subscribes to notifications', () {
      final spec = ViewModelSpec<_CounterVM>(builder: _CounterVM.new);
      final binding = _CountingBinding();
      addTearDown(binding.dispose);

      binding.read(spec).bump();
      expect(binding.updates, 0);

      binding.watch(spec).bump();
      expect(binding.updates, 1);
    });

    test('a hit after unbind restores direct ownership', () {
      final spec = ViewModelSpec<_CounterVM>(
        builder: _CounterVM.new,
        key: 'shared',
      );
      final owner = _CountingBinding();
      final other = _CountingBinding();
      addTearDown(owner.dispose);

      final vm = owner.read(spec);
      expect(other.read(spec), same(vm));

      owner.unbind(vm);
      expect(owner.read(spec), same(vm));

      // If the second read had skipped re-binding, disposing the only other
      // owner would recycle the instance.
      other.dispose();
      expect(vm.isDisposed, isFalse);
    });

    test('a recycled instance is never returned from the cache', () {
      final spec = ViewModelSpec<_CounterVM>(builder: _CounterVM.new);
      final binding = _CountingBinding();
      addTearDown(binding.dispose);

      final old = binding.read(spec);
      binding.recycle(old);

      final next = binding.read(spec);
      expect(old.isDisposed, isTrue);
      expect(next, isNot(same(old)));
      expect(next.isDisposed, isFalse);
      expect(binding.read(spec), same(next));
    });

    test('runtime reset invalidates cached resolutions', () {
      final spec = ViewModelSpec<_CounterVM>(builder: _CounterVM.new);
      final binding = _CountingBinding();
      addTearDown(binding.dispose);

      final old = binding.read(spec);
      ViewModel.reset();

      final next = binding.read(spec);
      expect(old.isDisposed, isTrue);
      expect(next, isNot(same(old)));
      expect(next.isDisposed, isFalse);
    });

    test('nested getter resolves a new child after recycle', () {
      final parentSpec = ViewModelSpec<_Parent>(builder: _Parent.new);
      final binding = _CountingBinding();
      addTearDown(binding.dispose);

      final parent = binding.read(parentSpec);
      final child = parent.child;
      expect(parent.child, same(child));

      binding.recycle(child);
      final next = parent.child;
      expect(next, isNot(same(child)));
      expect(next.isDisposed, isFalse);
    });

    test('aliveForever key validation runs on every resolution', () {
      final spec = ViewModelSpec<_CounterVM>(
        builder: _CounterVM.new,
        aliveForever: true,
      );
      final binding = _CountingBinding();
      addTearDown(binding.dispose);

      expect(() => binding.read(spec), throwsA(isA<ViewModelError>()));
      expect(() => binding.read(spec), throwsA(isA<ViewModelError>()));
    });
  });
}
