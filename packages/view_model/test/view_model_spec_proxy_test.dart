import 'package:flutter_test/flutter_test.dart';
import 'package:view_model/view_model.dart';

class TestBinder with ViewModelBinding {
  int updates = 0;
  @override
  void onUpdate() {
    super.onUpdate();
    updates++;
  }
}

class UserViewModel extends ViewModel {
  final String name;
  UserViewModel({required this.name});
}

void main() {
  group('ViewModelSpec Proxy', () {
    test('overrides builder, key, tag, isSingleton', () {
      final binder = TestBinder();
      final base = ViewModelSpec<UserViewModel>(
        builder: () => UserViewModel(name: 'Base'),
        key: 'base-key',
        tag: 'base-tag',
        isSingleton: false,
      );

      final override = ViewModelSpec<UserViewModel>(
        builder: () => UserViewModel(name: 'Override'),
        key: 'override-key',
        tag: 'override-tag',
        isSingleton: true,
      );

      base.setProxy(override);

      expect(base.key(), 'override-key');
      expect(base.tag(), 'override-tag');
      expect(base.singleton(), true);

      final vm = binder.viewModelBinding.watch(base);
      expect(vm.name, 'Override');
    });

    test('clearProxy restores original behavior', () {
      final binder = TestBinder();
      final base = ViewModelSpec<UserViewModel>(
        builder: () => UserViewModel(name: 'Base'),
        key: 'base-key',
        tag: 'base-tag',
        isSingleton: false,
      );

      final override = ViewModelSpec<UserViewModel>(
        builder: () => UserViewModel(name: 'Override'),
        key: 'override-key',
        tag: 'override-tag',
        isSingleton: true,
      );

      base.setProxy(override);
      base.clearProxy();

      expect(base.key(), 'base-key');
      expect(base.tag(), 'base-tag');
      expect(base.singleton(), false);

      final vm = binder.viewModelBinding.watch(base);
      expect(vm.name, 'Base');
    });
  });

  group('Arg Provider Proxy', () {
    test('arg overrides via proxy', () {
      final binder = TestBinder();
      final base = ViewModelSpec.arg<UserViewModel, String>(
        builder: (name) => UserViewModel(name: name),
        key: (name) => 'user-$name',
        tag: (name) => 't-$name',
        isSingleton: (name) => false,
      );
      final override = ViewModelSpecWithArg<UserViewModel, String>(
        builder: (name) => UserViewModel(name: 'Proxy-$name'),
        key: (name) => 'proxy-$name',
        tag: (name) => 'pt-$name',
        isSingleton: (name) => true,
      );
      base.setProxy(override);

      final vm1 = binder.viewModelBinding.watch(base('A'));
      final vm2 = binder.viewModelBinding.watch(base('A'));

      expect(vm1.name, 'Proxy-A');
      expect(identical(vm1, vm2), isTrue);
      expect(vm1.tag, 'pt-A');
    });

    test('arg clearProxy restores behavior', () {
      final binder = TestBinder();
      final base = ViewModelSpec.arg<UserViewModel, String>(
        builder: (name) => UserViewModel(name: name),
        key: (name) => 'user-$name',
        tag: (name) => 't-$name',
      );
      final override = ViewModelSpecWithArg<UserViewModel, String>(
        builder: (name) => UserViewModel(name: 'Proxy-$name'),
        key: (name) => 'proxy-$name',
        tag: (name) => 'pt-$name',
      );
      base.setProxy(override);
      base.clearProxy();

      final vm = binder.viewModelBinding.watch(base('A'));
      expect(vm.name, 'A');
      expect(vm.tag, 't-A');
    });

    test('arg2 overrides via proxy', () {
      final binder = TestBinder();
      final base = ViewModelSpec.arg2<UserViewModel, String, int>(
        builder: (name, _) => UserViewModel(name: name),
        key: (name, _) => 'user-$name',
      );
      final override = ViewModelSpecWithArg2<UserViewModel, String, int>(
        builder: (name, _) => UserViewModel(name: 'P2-$name'),
        key: (name, _) => 'p2-$name',
        tag: (name, _) => 't2-$name',
        isSingleton: (name, _) => true,
      );
      base.setProxy(override);

      final vm1 = binder.viewModelBinding.watch(base('A', 1));
      final vm2 = binder.viewModelBinding.watch(base('A', 1));
      expect(vm1.name, 'P2-A');
      expect(identical(vm1, vm2), isTrue);
      expect(vm1.tag, 't2-A');
    });

    test('arg2 clearProxy restores behavior', () {
      final binder = TestBinder();
      final base = ViewModelSpec.arg2<UserViewModel, String, int>(
        builder: (name, _) => UserViewModel(name: name),
        key: (name, _) => 'user-$name',
      );
      final override = ViewModelSpecWithArg2<UserViewModel, String, int>(
        builder: (name, _) => UserViewModel(name: 'P2-$name'),
        key: (name, _) => 'p2-$name',
        tag: (name, _) => 't2-$name',
        isSingleton: (name, _) => true,
      );
      base.setProxy(override);
      base.clearProxy();

      final vm1 = binder.viewModelBinding.watch(base('A', 1));
      expect(vm1.name, 'A');
    });

    test('arg3 overrides via proxy', () {
      final binder = TestBinder();
      final base = ViewModelSpec.arg3<UserViewModel, String, int, bool>(
        builder: (name, _, __) => UserViewModel(name: name),
        key: (name, _, __) => 'user-$name',
      );
      final override =
          ViewModelSpecWithArg3<UserViewModel, String, int, bool>(
        builder: (name, _, __) => UserViewModel(name: 'P3-$name'),
        key: (name, _, __) => 'p3-$name',
        tag: (name, _, __) => 't3-$name',
        isSingleton: (name, _, __) => true,
      );
      base.setProxy(override);

      final vm1 = binder.viewModelBinding.watch(base('A', 1, true));
      final vm2 = binder.viewModelBinding.watch(base('A', 1, true));
      expect(vm1.name, 'P3-A');
      expect(identical(vm1, vm2), isTrue);
      expect(vm1.tag, 't3-A');
    });

    test('arg3 clearProxy restores behavior', () {
      final binder = TestBinder();
      final base = ViewModelSpec.arg3<UserViewModel, String, int, bool>(
        builder: (name, _, __) => UserViewModel(name: name),
        key: (name, _, __) => 'user-$name',
      );
      final override =
          ViewModelSpecWithArg3<UserViewModel, String, int, bool>(
        builder: (name, _, __) => UserViewModel(name: 'P3-$name'),
      );
      base.setProxy(override);
      base.clearProxy();

      final vm1 = binder.viewModelBinding.watch(base('A', 1, true));
      expect(vm1.name, 'A');
    });

    test('arg4 overrides via proxy', () {
      final binder = TestBinder();
      final base =
          ViewModelSpec.arg4<UserViewModel, String, int, bool, double>(
        builder: (name, _, __, ___) => UserViewModel(name: name),
        key: (name, _, __, ___) => 'user-$name',
      );
      final override =
          ViewModelSpecWithArg4<UserViewModel, String, int, bool, double>(
        builder: (name, _, __, ___) => UserViewModel(name: 'P4-$name'),
        key: (name, _, __, ___) => 'p4-$name',
        tag: (name, _, __, ___) => 't4-$name',
        isSingleton: (name, _, __, ___) => true,
      );
      base.setProxy(override);

      final vm1 = binder.viewModelBinding.watch(base('A', 1, true, 1.0));
      final vm2 = binder.viewModelBinding.watch(base('A', 1, true, 1.0));
      expect(vm1.name, 'P4-A');
      expect(identical(vm1, vm2), isTrue);
      expect(vm1.tag, 't4-A');
    });

    test('arg4 clearProxy restores behavior', () {
      final binder = TestBinder();
      final base =
          ViewModelSpec.arg4<UserViewModel, String, int, bool, double>(
        builder: (name, _, __, ___) => UserViewModel(name: name),
        key: (name, _, __, ___) => 'user-$name',
      );
      final override =
          ViewModelSpecWithArg4<UserViewModel, String, int, bool, double>(
        builder: (name, _, __, ___) => UserViewModel(name: 'P4-$name'),
      );
      base.setProxy(override);
      base.clearProxy();

      final vm1 = binder.viewModelBinding.watch(base('A', 1, true, 1.0));
      expect(vm1.name, 'A');
    });
  });
}
