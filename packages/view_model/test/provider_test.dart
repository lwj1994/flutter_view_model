import 'package:flutter_test/flutter_test.dart';
import 'package:view_model/view_model.dart';

// A simple ViewModel for testing.
class CounterViewModel extends ViewModel {
  int count = 0;

  void increment() {
    count++;
    notifyListeners();
  }
}

// A ViewModel that takes an argument.
class UserViewModel extends ViewModel {
  final String name;

  UserViewModel({required this.name});
}

// A mock binder to simulate the widget environment.
class TestBinder with Refer {
  int updates = 0;

  void onUpdate() {
    super.onUpdate();
    updates++;
  }
}

// Another ViewModel for testing singleton with different types.
class AnotherCounterViewModel extends CounterViewModel {}

void main() {
  group('ViewModelProvider', () {
    test('creates and watches a ViewModel', () {
      final binder = TestBinder();
      final spec = ViewModelProvider<CounterViewModel>(
        builder: () => CounterViewModel(),
      );

      final vm = binder.refer.watch(spec);
      expect(vm, isA<CounterViewModel>());
      expect(vm.count, 0);

      vm.increment();
      expect(vm.count, 1);
      expect(binder.updates, 1);
    });

    test('reuses the same instance when watched multiple times', () {
      final binder = TestBinder();
      final spec = ViewModelProvider<CounterViewModel>(
        builder: () => CounterViewModel(),
      );

      final vm1 = binder.refer.watch(spec);
      final vm2 = binder.refer.watch(spec);

      expect(identical(vm1, vm2), isTrue);
    });

    test('uses key to cache instance', () {
      final binder = TestBinder();
      final spec1 = ViewModelProvider<CounterViewModel>(
        builder: () => CounterViewModel(),
        key: 'counter',
      );
      final spec2 = ViewModelProvider<CounterViewModel>(
        builder: () => CounterViewModel(),
        key: 'counter',
      );
      final spec3 = ViewModelProvider<CounterViewModel>(
        builder: () => CounterViewModel(),
        key: 'another-counter',
      );

      final vm1 = binder.refer.watch(spec1);
      final vm2 = binder.refer.watch(spec2);
      final vm3 = binder.refer.watch(spec3);

      expect(identical(vm1, vm2), isTrue);
      expect(identical(vm1, vm3), isFalse);
    });

    test('toFactory creates a valid factory', () {
      final spec = ViewModelProvider<CounterViewModel>(
        builder: () => CounterViewModel(),
        key: 'counter',
        isSingleton: true,
      );

      final factory = spec;
      expect(factory, isA<ViewModelFactory<CounterViewModel>>());

      final binder = TestBinder();
      final vm1 = binder.refer.watch(factory);
      final vm2 = binder.refer.watch(factory);

      expect(identical(vm1, vm2), isTrue);
    });

    test('isSingleton provides a default key', () {
      final binder = TestBinder();
      final spec1 = ViewModelProvider<CounterViewModel>(
        builder: () => CounterViewModel(),
        isSingleton: true,
      );
      final spec2 = ViewModelProvider<CounterViewModel>(
        builder: () => CounterViewModel(),
        isSingleton: true,
      );

      final vm1 = binder.refer.watch(spec1);
      final vm2 = binder.refer.watch(spec2);

      expect(identical(vm1, vm2), isTrue);
    });

    test('isSingleton provides a different key for different types', () {
      final binder = TestBinder();
      final spec1 = ViewModelProvider<CounterViewModel>(
        builder: () => CounterViewModel(),
        isSingleton: true,
      );
      final spec2 = ViewModelProvider<AnotherCounterViewModel>(
        builder: () => AnotherCounterViewModel(),
        isSingleton: true,
      );

      final vm1 = binder.refer.watch(spec1);
      final vm2 = binder.refer.watch(spec2);

      expect(identical(vm1, vm2), isFalse);
    });
  });

  group('ViewModelProviderWithArg', () {
    test('creates a ViewModel with an argument', () {
      final binder = TestBinder();
      final spec = ViewModelProvider.arg<UserViewModel, String>(
        builder: (name) => UserViewModel(name: name),
      );

      final vm = binder.refer.watch(spec('Alice'));
      expect(vm, isA<UserViewModel>());
      expect(vm.name, 'Alice');
    });

    test('caches instances based on argument', () {
      final binder = TestBinder();
      final spec = ViewModelProvider.arg<UserViewModel, String>(
        builder: (name) => UserViewModel(name: name),
        key: (name) => 'user-$name',
      );

      final vm1 = binder.refer.watch(spec('Alice'));
      final vm2 = binder.refer.watch(spec('Alice'));
      final vm3 = binder.refer.watch(spec('Bob'));

      expect(identical(vm1, vm2), isTrue);
      expect(identical(vm1, vm3), isFalse);
      expect(vm3.name, 'Bob');
    });

    test('caches instances based on complex argument', () {
      final binder = TestBinder();
      final spec = ViewModelProvider.arg<UserViewModel, ComplexArg>(
        builder: (arg) => UserViewModel(name: arg.name),
        key: (arg) => 'user-${arg.id}',
      );

      final arg1 = ComplexArg('1', 'Alice');
      final arg2 = ComplexArg('1', 'Alice');
      final arg3 = ComplexArg('2', 'Bob');

      final vm1 = binder.refer.watch(spec(arg1));
      final vm2 = binder.refer.watch(spec(arg2));
      final vm3 = binder.refer.watch(spec(arg3));

      expect(identical(vm1, vm2), isTrue);
      expect(identical(vm1, vm3), isFalse);
      expect(vm3.name, 'Bob');
    });

    test('toFactory creates a valid factory with arg', () {
      final spec = ViewModelProvider.arg<UserViewModel, String>(
        builder: (name) => UserViewModel(name: name),
        key: (name) => 'user-$name',
      );

      final factory = spec('Alice');
      expect(factory, isA<ViewModelFactory<UserViewModel>>());

      final binder = TestBinder();
      final vm1 = binder.refer.watch(factory);
      final vm2 = binder.refer.watch(factory);

      expect(identical(vm1, vm2), isTrue);
      expect(vm1.name, 'Alice');
    });
  });
}

class ComplexArg {
  final String id;
  final String name;

  ComplexArg(this.id, this.name);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ComplexArg &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name;

  @override
  int get hashCode => id.hashCode ^ name.hashCode;
}
