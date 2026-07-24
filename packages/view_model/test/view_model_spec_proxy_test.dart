import 'dart:async';

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

String _resolveName(ViewModelFactory<UserViewModel> factory) {
  final binding = TestBinder();
  try {
    return binding.read(factory).name;
  } finally {
    binding.dispose();
  }
}

void main() {
  group('ViewModelSpec Proxy', () {
    test('overrides builder, key, tag', () {
      final binder = TestBinder();
      addTearDown(binder.dispose);
      final base = ViewModelSpec<UserViewModel>(
        builder: () => UserViewModel(name: 'Base'),
        key: 'base-key',
        tag: 'base-tag',
      );

      final override = ViewModelSpec<UserViewModel>(
        builder: () => UserViewModel(name: 'Override'),
        key: 'override-key',
        tag: 'override-tag',
      );

      base.setProxy(override);

      expect(base.key(), 'override-key');
      expect(base.tag(), 'override-tag');

      final vm = binder.watch(base);
      expect(vm.name, 'Override');
    });

    test('clearProxy restores original behavior', () {
      final binder = TestBinder();
      addTearDown(binder.dispose);
      final base = ViewModelSpec<UserViewModel>(
        builder: () => UserViewModel(name: 'Base'),
        key: 'base-key',
        tag: 'base-tag',
      );

      final override = ViewModelSpec<UserViewModel>(
        builder: () => UserViewModel(name: 'Override'),
        key: 'override-key',
        tag: 'override-tag',
      );

      base.setProxy(override);
      base.clearProxy();

      expect(base.key(), 'base-key');
      expect(base.tag(), 'base-tag');

      final vm = binder.watch(base);
      expect(vm.name, 'Base');
    });

    test('overrideWith restores nested overrides and is idempotent', () {
      final base = ViewModelSpec<UserViewModel>(
        builder: () => UserViewModel(name: 'Base'),
      );
      final first = ViewModelSpec<UserViewModel>(
        builder: () => UserViewModel(name: 'First'),
      );
      final second = ViewModelSpec<UserViewModel>(
        builder: () => UserViewModel(name: 'Second'),
      );

      final restoreFirst = base.overrideWith(first);
      expect(_resolveName(base), 'First');

      final restoreSecond = base.overrideWith(second);
      expect(_resolveName(base), 'Second');

      restoreSecond();
      expect(_resolveName(base), 'First');

      restoreSecond();
      expect(_resolveName(base), 'First');

      restoreFirst();
      expect(_resolveName(base), 'Base');
    });

    test('overrideWith supports out-of-order restore', () {
      final base = ViewModelSpec<UserViewModel>(
        builder: () => UserViewModel(name: 'Base'),
      );
      final first = ViewModelSpec<UserViewModel>(
        builder: () => UserViewModel(name: 'First'),
      );
      final second = ViewModelSpec<UserViewModel>(
        builder: () => UserViewModel(name: 'Second'),
      );

      final restoreFirst = base.overrideWith(first);
      final restoreSecond = base.overrideWith(second);

      restoreFirst();
      expect(_resolveName(base), 'Second');

      restoreSecond();
      expect(_resolveName(base), 'Base');
    });

    test('overrideWith restores a legacy setProxy override', () {
      final base = ViewModelSpec<UserViewModel>(
        builder: () => UserViewModel(name: 'Base'),
      );
      final legacy = ViewModelSpec<UserViewModel>(
        builder: () => UserViewModel(name: 'Legacy'),
      );
      final scoped = ViewModelSpec<UserViewModel>(
        builder: () => UserViewModel(name: 'Scoped'),
      );

      base.setProxy(legacy);
      final restore = base.overrideWith(scoped);
      expect(_resolveName(base), 'Scoped');

      restore();
      expect(_resolveName(base), 'Legacy');

      base.clearProxy();
      expect(_resolveName(base), 'Base');
    });

    test('legacy proxy changes do not cancel an active scoped override', () {
      final base = ViewModelSpec<UserViewModel>(
        builder: () => UserViewModel(name: 'Base'),
      );
      final legacy = ViewModelSpec<UserViewModel>(
        builder: () => UserViewModel(name: 'Legacy'),
      );
      final replacement = ViewModelSpec<UserViewModel>(
        builder: () => UserViewModel(name: 'Replacement'),
      );
      final scoped = ViewModelSpec<UserViewModel>(
        builder: () => UserViewModel(name: 'Scoped'),
      );

      base.setProxy(legacy);
      final restore = base.overrideWith(scoped);
      base.setProxy(replacement);
      expect(_resolveName(base), 'Scoped');

      restore();
      expect(_resolveName(base), 'Replacement');

      final restoreAfterClear = base.overrideWith(scoped);
      base.clearProxy();
      expect(_resolveName(base), 'Scoped');
      restoreAfterClear();
      expect(_resolveName(base), 'Base');
    });

    test('runWithOverride restores after async success', () async {
      final base = ViewModelSpec<UserViewModel>(
        builder: () => UserViewModel(name: 'Base'),
      );
      final override = ViewModelSpec<UserViewModel>(
        builder: () => UserViewModel(name: 'Override'),
      );

      final result = await base.runWithOverride(override, () async {
        expect(_resolveName(base), 'Override');
        await Future<void>.delayed(Duration.zero);
        expect(_resolveName(base), 'Override');
        return 42;
      });

      expect(result, 42);
      expect(_resolveName(base), 'Base');
    });

    test('runWithOverride restores the outer override when nested', () async {
      final base = ViewModelSpec<UserViewModel>(
        builder: () => UserViewModel(name: 'Base'),
      );
      final outer = ViewModelSpec<UserViewModel>(
        builder: () => UserViewModel(name: 'Outer'),
      );
      final inner = ViewModelSpec<UserViewModel>(
        builder: () => UserViewModel(name: 'Inner'),
      );

      await base.runWithOverride<void>(outer, () async {
        expect(_resolveName(base), 'Outer');

        await base.runWithOverride<void>(inner, () async {
          await Future<void>.delayed(Duration.zero);
          expect(_resolveName(base), 'Inner');
        });

        expect(_resolveName(base), 'Outer');
      });

      expect(_resolveName(base), 'Base');
    });

    test('runWithOverride isolates overlapping async bodies', () async {
      final base = ViewModelSpec<UserViewModel>(
        builder: () => UserViewModel(name: 'Base'),
      );
      final first = ViewModelSpec<UserViewModel>(
        builder: () => UserViewModel(name: 'First'),
      );
      final second = ViewModelSpec<UserViewModel>(
        builder: () => UserViewModel(name: 'Second'),
      );
      final firstEntered = Completer<void>();
      final secondEntered = Completer<void>();
      final releaseSecond = Completer<void>();
      final observations = <String>[];

      final firstRun = base.runWithOverride<void>(first, () async {
        firstEntered.complete();
        await secondEntered.future;
        observations.add('first:${_resolveName(base)}');
        releaseSecond.complete();
      });
      final secondRun = base.runWithOverride<void>(second, () async {
        await firstEntered.future;
        secondEntered.complete();
        await releaseSecond.future;
        observations.add('second:${_resolveName(base)}');
      });

      await Future.wait([firstRun, secondRun]);

      expect(observations, ['first:First', 'second:Second']);
      expect(_resolveName(base), 'Base');
    });

    test('runWithOverride restores after synchronous failure', () async {
      final base = ViewModelSpec<UserViewModel>(
        builder: () => UserViewModel(name: 'Base'),
      );
      final override = ViewModelSpec<UserViewModel>(
        builder: () => UserViewModel(name: 'Override'),
      );

      await expectLater(
        base.runWithOverride<void>(override, () {
          expect(_resolveName(base), 'Override');
          throw StateError('sync failure');
        }),
        throwsStateError,
      );
      expect(_resolveName(base), 'Base');
    });

    test('runWithOverride restores after asynchronous failure', () async {
      final base = ViewModelSpec<UserViewModel>(
        builder: () => UserViewModel(name: 'Base'),
      );
      final override = ViewModelSpec<UserViewModel>(
        builder: () => UserViewModel(name: 'Override'),
      );

      await expectLater(
        base.runWithOverride<void>(override, () async {
          await Future<void>.delayed(Duration.zero);
          expect(_resolveName(base), 'Override');
          throw StateError('async failure');
        }),
        throwsStateError,
      );
      expect(_resolveName(base), 'Base');
    });
  });

  group('Arg Provider Proxy', () {
    test('arg overrides via proxy', () {
      final binder = TestBinder();
      addTearDown(binder.dispose);
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

      final vm1 = binder.watch(base('A'));
      final vm2 = binder.watch(base('A'));

      expect(vm1.name, 'Proxy-A');
      expect(identical(vm1, vm2), isTrue);
      expect(vm1.tag, 'pt-A');
    });

    test('arg clearProxy restores behavior', () {
      final binder = TestBinder();
      addTearDown(binder.dispose);
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

      final vm = binder.watch(base('A'));
      expect(vm.name, 'A');
      expect(vm.tag, 't-A');
    });

    test('arg2 overrides via proxy', () {
      final binder = TestBinder();
      addTearDown(binder.dispose);
      final base = ViewModelSpec.arg2<UserViewModel, String, int>(
        builder: (name, _) => UserViewModel(name: name),
        key: (name, _) => 'user-$name',
      );
      final override = ViewModelSpecWithArg2<UserViewModel, String, int>(
        builder: (name, _) => UserViewModel(name: 'P2-$name'),
        key: (name, _) => 'p2-$name',
        tag: (name, _) => 't2-$name',
      );
      base.setProxy(override);

      final vm1 = binder.watch(base('A', 1));
      final vm2 = binder.watch(base('A', 1));
      expect(vm1.name, 'P2-A');
      expect(identical(vm1, vm2), isTrue);
      expect(vm1.tag, 't2-A');
    });

    test('arg2 clearProxy restores behavior', () {
      final binder = TestBinder();
      addTearDown(binder.dispose);
      final base = ViewModelSpec.arg2<UserViewModel, String, int>(
        builder: (name, _) => UserViewModel(name: name),
        key: (name, _) => 'user-$name',
      );
      final override = ViewModelSpecWithArg2<UserViewModel, String, int>(
        builder: (name, _) => UserViewModel(name: 'P2-$name'),
        key: (name, _) => 'p2-$name',
        tag: (name, _) => 't2-$name',
      );
      base.setProxy(override);
      base.clearProxy();

      final vm1 = binder.watch(base('A', 1));
      expect(vm1.name, 'A');
    });

    test('arg3 overrides via proxy', () {
      final binder = TestBinder();
      addTearDown(binder.dispose);
      final base = ViewModelSpec.arg3<UserViewModel, String, int, bool>(
        builder: (name, _, __) => UserViewModel(name: name),
        key: (name, _, __) => 'user-$name',
      );
      final override = ViewModelSpecWithArg3<UserViewModel, String, int, bool>(
        builder: (name, _, __) => UserViewModel(name: 'P3-$name'),
        key: (name, _, __) => 'p3-$name',
        tag: (name, _, __) => 't3-$name',
      );
      base.setProxy(override);

      final vm1 = binder.watch(base('A', 1, true));
      final vm2 = binder.watch(base('A', 1, true));
      expect(vm1.name, 'P3-A');
      expect(identical(vm1, vm2), isTrue);
      expect(vm1.tag, 't3-A');
    });

    test('arg3 clearProxy restores behavior', () {
      final binder = TestBinder();
      addTearDown(binder.dispose);
      final base = ViewModelSpec.arg3<UserViewModel, String, int, bool>(
        builder: (name, _, __) => UserViewModel(name: name),
        key: (name, _, __) => 'user-$name',
      );
      final override = ViewModelSpecWithArg3<UserViewModel, String, int, bool>(
        builder: (name, _, __) => UserViewModel(name: 'P3-$name'),
      );
      base.setProxy(override);
      base.clearProxy();

      final vm1 = binder.watch(base('A', 1, true));
      expect(vm1.name, 'A');
    });

    test('arg4 overrides via proxy', () {
      final binder = TestBinder();
      addTearDown(binder.dispose);
      final base = ViewModelSpec.arg4<UserViewModel, String, int, bool, double>(
        builder: (name, _, __, ___) => UserViewModel(name: name),
        key: (name, _, __, ___) => 'user-$name',
      );
      final override =
          ViewModelSpecWithArg4<UserViewModel, String, int, bool, double>(
        builder: (name, _, __, ___) => UserViewModel(name: 'P4-$name'),
        key: (name, _, __, ___) => 'p4-$name',
        tag: (name, _, __, ___) => 't4-$name',
      );
      base.setProxy(override);

      final vm1 = binder.watch(base('A', 1, true, 1.0));
      final vm2 = binder.watch(base('A', 1, true, 1.0));
      expect(vm1.name, 'P4-A');
      expect(identical(vm1, vm2), isTrue);
      expect(vm1.tag, 't4-A');
    });

    test('arg4 clearProxy restores behavior', () {
      final binder = TestBinder();
      addTearDown(binder.dispose);
      final base = ViewModelSpec.arg4<UserViewModel, String, int, bool, double>(
        builder: (name, _, __, ___) => UserViewModel(name: name),
        key: (name, _, __, ___) => 'user-$name',
      );
      final override =
          ViewModelSpecWithArg4<UserViewModel, String, int, bool, double>(
        builder: (name, _, __, ___) => UserViewModel(name: 'P4-$name'),
      );
      base.setProxy(override);
      base.clearProxy();

      final vm1 = binder.watch(base('A', 1, true, 1.0));
      expect(vm1.name, 'A');
    });

    test('overrideWith is available for arg through arg4 specs', () {
      final arg = ViewModelSpec.arg<UserViewModel, String>(
        builder: (name) => UserViewModel(name: 'arg-$name'),
      );
      final argOverride = ViewModelSpec.arg<UserViewModel, String>(
        builder: (name) => UserViewModel(name: 'override-$name'),
      );
      final restoreArg = arg.overrideWith(argOverride);
      expect(_resolveName(arg('A')), 'override-A');
      restoreArg();
      expect(_resolveName(arg('A')), 'arg-A');

      final arg2 = ViewModelSpec.arg2<UserViewModel, String, int>(
        builder: (name, count) => UserViewModel(name: 'arg2-$name-$count'),
      );
      final arg2Override = ViewModelSpec.arg2<UserViewModel, String, int>(
        builder: (name, count) => UserViewModel(name: 'override2-$name-$count'),
      );
      final restoreArg2 = arg2.overrideWith(arg2Override);
      expect(_resolveName(arg2('A', 2)), 'override2-A-2');
      restoreArg2();
      expect(_resolveName(arg2('A', 2)), 'arg2-A-2');

      final arg3 = ViewModelSpec.arg3<UserViewModel, String, int, bool>(
        builder: (name, count, enabled) =>
            UserViewModel(name: 'arg3-$name-$count-$enabled'),
      );
      final arg3Override = ViewModelSpec.arg3<UserViewModel, String, int, bool>(
        builder: (name, count, enabled) =>
            UserViewModel(name: 'override3-$name-$count-$enabled'),
      );
      final restoreArg3 = arg3.overrideWith(arg3Override);
      expect(_resolveName(arg3('A', 3, true)), 'override3-A-3-true');
      restoreArg3();
      expect(_resolveName(arg3('A', 3, true)), 'arg3-A-3-true');

      final arg4 = ViewModelSpec.arg4<UserViewModel, String, int, bool, double>(
        builder: (name, count, enabled, ratio) =>
            UserViewModel(name: 'arg4-$name-$count-$enabled-$ratio'),
      );
      final arg4Override =
          ViewModelSpec.arg4<UserViewModel, String, int, bool, double>(
        builder: (name, count, enabled, ratio) =>
            UserViewModel(name: 'override4-$name-$count-$enabled-$ratio'),
      );
      final restoreArg4 = arg4.overrideWith(arg4Override);
      expect(
        _resolveName(arg4('A', 4, true, 0.5)),
        'override4-A-4-true-0.5',
      );
      restoreArg4();
      expect(_resolveName(arg4('A', 4, true, 0.5)), 'arg4-A-4-true-0.5');
    });
  });
}
