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
class TestBinder with Vef {
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

      final vm = binder.vef.watch(spec);
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

      final vm1 = binder.vef.watch(spec);
      final vm2 = binder.vef.watch(spec);

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

      final vm1 = binder.vef.watch(spec1);
      final vm2 = binder.vef.watch(spec2);
      final vm3 = binder.vef.watch(spec3);

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
      final vm1 = binder.vef.watch(factory);
      final vm2 = binder.vef.watch(factory);

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

      final vm1 = binder.vef.watch(spec1);
      final vm2 = binder.vef.watch(spec2);

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

      final vm1 = binder.vef.watch(spec1);
      final vm2 = binder.vef.watch(spec2);

      expect(identical(vm1, vm2), isFalse);
    });
  });

  group('ViewModelProviderWithArg', () {
    test('creates a ViewModel with an argument', () {
      final binder = TestBinder();
      final spec = ViewModelProvider.arg<UserViewModel, String>(
        builder: (name) => UserViewModel(name: name),
      );

      final vm = binder.vef.watch(spec('Alice'));
      expect(vm, isA<UserViewModel>());
      expect(vm.name, 'Alice');
    });

    test('caches instances based on argument', () {
      final binder = TestBinder();
      final spec = ViewModelProvider.arg<UserViewModel, String>(
        builder: (name) => UserViewModel(name: name),
        key: (name) => 'user-$name',
      );

      final vm1 = binder.vef.watch(spec('Alice'));
      final vm2 = binder.vef.watch(spec('Alice'));
      final vm3 = binder.vef.watch(spec('Bob'));

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

      final vm1 = binder.vef.watch(spec(arg1));
      final vm2 = binder.vef.watch(spec(arg2));
      final vm3 = binder.vef.watch(spec(arg3));

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
      final vm1 = binder.vef.watch(factory);
      final vm2 = binder.vef.watch(factory);

      expect(identical(vm1, vm2), isTrue);
      expect(vm1.name, 'Alice');
    });
  });

  group('ViewModelProvider Args', () {
    test('arg providers build correct instances', () {
      final p1 = ViewModelProvider.arg<TestModel, int>(
        builder: (a) => TestModel(),
      );
      final factory1 = p1(1);
      expect(factory1.build(), isA<TestModel>());

      final p2 = ViewModelProvider.arg2<TestModel, int, String>(
        builder: (a, b) => TestModel(),
      );
      final factory2 = p2(1, 'a');
      expect(factory2.build(), isA<TestModel>());

      final p3 = ViewModelProvider.arg3<TestModel, int, String, bool>(
        builder: (a, b, c) => TestModel(),
      );
      final factory3 = p3(1, 'a', true);
      expect(factory3.build(), isA<TestModel>());

      final p4 = ViewModelProvider.arg4<TestModel, int, String, bool, double>(
        builder: (a, b, c, d) => TestModel(),
      );
      final factory4 = p4(1, 'a', true, 1.0);
      expect(factory4.build(), isA<TestModel>());
    });

    test('creates correct factory properties', () {
      final provider = ViewModelProvider(
        builder: () => TestModel(),
        key: 'key1',
        tag: 'tag1',
        isSingleton: true,
      );

      expect(provider.key(), 'key1');
      expect(provider.tag(), 'tag1');
      expect(provider.singleton(), true);
      expect(provider.build(), isA<TestModel>());
    });

    test('arg provider creates correct factory properties', () {
      final argProvider = ViewModelProvider.arg<TestModel, int>(
        builder: (i) => TestModel(),
        key: (i) => 'key$i',
        tag: (i) => 'tag$i',
        isSingleton: (i) => i % 2 == 0,
      );

      final factory1 = argProvider(1);
      expect(factory1.key(), 'key1');
      expect(factory1.tag(), 'tag1');
      expect(factory1.singleton(), false);

      final factory2 = argProvider(2);
      expect(factory2.key(), 'key2');
      expect(factory2.tag(), 'tag2');
      expect(factory2.singleton(), true);
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

class TestModel extends ViewModel {}
