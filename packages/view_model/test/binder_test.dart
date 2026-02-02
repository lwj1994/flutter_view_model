import 'package:flutter_test/flutter_test.dart';
import 'package:view_model/src/view_model/state_store.dart';
import 'package:view_model/view_model.dart';

// 1. Define a simple ViewModel
class TestViewModel extends ViewModel {
  int count = 0;
  Future<void> increment() async {
    update(() {
      count++;
    });
  }
}

class TestViewModelFactory with ViewModelFactory<TestViewModel> {
  @override
  TestViewModel build() => TestViewModel();
}

// 2. Define a ViewModel that tracks disposal
class DisposableViewModel extends ViewModel {
  bool isDisposed = false;
  @override
  void dispose() {
    isDisposed = true;
    super.dispose();
  }
}

class DisposableViewModelFactory with ViewModelFactory<DisposableViewModel> {
  @override
  DisposableViewModel build() => DisposableViewModel();
}

// 3. Define a TestBinder that mixes in ViewModelBinding
class TestBinder with ViewModelBinding {
  int updateCount = 0;

  @override
  void onUpdate() {
    super.onUpdate();
    updateCount++;
  }
}

void main() {
  group('ViewModelBinding Tests', () {
    test('ViewModelBinding can create and watch ViewModel', () async {
      final binder = TestBinder();
      final vm = binder.viewModelBinding.watch(TestViewModelFactory());

      expect(vm, isA<TestViewModel>());
      expect(vm.count, 0);

      // Verify initial state
      expect(binder.updateCount, 0);

      // Trigger update
      await vm.increment();

      // Verify onUpdate called
      expect(vm.count, 1);
      expect(binder.updateCount, 1);

      binder.dispose();
    });

    test('ViewModelBinding disposes ViewModel when disposed', () {
      final binder = TestBinder();
      final vm = binder.viewModelBinding.watch(DisposableViewModelFactory());

      expect(vm.isDisposed, false);

      binder.dispose();

      // Since binder is the only one holding the VM, it should be disposed.
      expect(vm.isDisposed, true);
    });

    test('Multiple Binded Refs sharing ViewModel', () {
      final binder1 = TestBinder();
      final binder2 = TestBinder();

      // Use a key to share instance
      final factory = ViewModelSpec<DisposableViewModel>(
        builder: () => DisposableViewModel(),
        key: 'shared_vm',
      );

      final vm1 = binder1.viewModelBinding.watch(factory);
      final vm2 = binder2.viewModelBinding.watch(factory);

      expect(vm1, equals(vm2));

      // Dispose binder1
      binder1.dispose();
      // VM should still be alive because binder2 holds it
      expect(vm1.isDisposed, false);

      // Dispose binder2
      binder2.dispose();
      // Now VM should be disposed
      expect(vm1.isDisposed, true);
    });

    test('ViewModelBinding can read ViewModel without listening', () {
      final binder = TestBinder();
      final vm = binder.viewModelBinding.read(TestViewModelFactory());

      expect(vm.count, 0);

      // Trigger update
      vm.increment();

      // Verify onUpdate NOT called
      expect(vm.count, 1);
      expect(binder.updateCount, 0);

      binder.dispose();
    });

    test('ViewModelBinding recycleViewModel forces recreation', () {
      final binder = TestBinder();
      final factory = TestViewModelFactory();

      final vm1 = binder.viewModelBinding.watch(factory);
      vm1.increment();
      expect(vm1.count, 1);

      // Recycle
      binder.viewModelBinding.recycle(vm1);

      // onUpdate should be called during recycle (to refresh host)
      expect(binder.updateCount, 1);

      // Watch again, should get a new instance
      final vm2 = binder.viewModelBinding.watch(factory);
      expect(vm2, isNot(equals(vm1)));
      expect(vm2.count, 0); // New instance state

      binder.dispose();
    });

    test('ViewModelBinding init and dispose lifecycle', () {
      final binder = TestBinder();
      binder.init(); // Should not throw
      expect(binder.isDisposed, false);

      binder.dispose();
      expect(binder.isDisposed, true);

      // Creating VM after dispose should throw
      expect(
        () => binder.viewModelBinding.watch(TestViewModelFactory()),
        throwsA(isA<ViewModelError>()),
      );
    });
  });
}
