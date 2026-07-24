import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:view_model/src/devtool/tracker.dart';
import 'package:view_model/src/get_instance/manager.dart';
import 'package:view_model/src/view_model/state_store.dart' show ViewModelError;
import 'package:view_model/view_model.dart';

class DiagnosticViewModel with ViewModel {
  DiagnosticViewModel(this.value);

  final int value;
}

class DiagnosticFactory with ViewModelFactory<DiagnosticViewModel> {
  const DiagnosticFactory();

  @override
  DiagnosticViewModel build() => DiagnosticViewModel(1);
}

class AlwaysEqualViewModel with ViewModel {
  @override
  bool operator ==(Object other) => other is AlwaysEqualViewModel;

  @override
  int get hashCode => 0;
}

final _ownerDependencySpec = ViewModelSpec<DiagnosticViewModel>(
  builder: () => DiagnosticViewModel(42),
  key: 'owner-dependency',
);

final _sharedOwnerSpec = ViewModelSpec<_OwnerViewModel>(
  builder: _OwnerViewModel.new,
  key: 'equal-binding-shared-owner',
);

class _OwnerViewModel with ViewModel {
  DiagnosticViewModel get dependency =>
      viewModelBinding.read(_ownerDependencySpec);

  ViewModelBindingInterface get owner => viewModelBinding;
}

class _AlwaysEqualBinding with ViewModelBinding {
  _OwnerViewModel get viewModel => read(_sharedOwnerSpec);

  @override
  bool operator ==(Object other) => other is _AlwaysEqualBinding;

  @override
  int get hashCode => 0;
}

class ReentrantDisposeViewModel with ViewModel {
  ReentrantDisposeViewModel(this.binding);

  final ViewModelBinding binding;
  Object? resolutionError;

  @override
  void dispose() {
    try {
      binding.read(
        ViewModelSpec<DiagnosticViewModel>(
          builder: () => DiagnosticViewModel(99),
          key: 'created-during-reset',
        ),
      );
    } catch (error) {
      resolutionError = error;
    }
    super.dispose();
  }
}

void main() {
  late DebugPrintCallback originalDebugPrint;

  setUp(() {
    originalDebugPrint = debugPrint;
    ViewModel.reset();
  });

  tearDown(() {
    debugPrint = originalDebugPrint;
    ViewModel.reset();
  });

  test('ambiguous cached lookup silently keeps latest-instance behavior', () {
    final binding = ViewModelBinding();
    final first = binding.read(
      ViewModelSpec(
        builder: () => DiagnosticViewModel(1),
        key: 'diagnostic-1',
      ),
    );
    final second = binding.read(
      ViewModelSpec(
        builder: () => DiagnosticViewModel(2),
        key: 'diagnostic-2',
      ),
    );
    final cached = ViewModel.readCached<DiagnosticViewModel>();

    expect(cached, same(second));
    expect(cached, isNot(same(first)));
    binding.dispose();
  });

  test('different specs with the same implicit identity emit a warning', () {
    final binding = ViewModelBinding();
    var secondBuilderCalls = 0;
    final firstSpec = ViewModelSpec<DiagnosticViewModel>(
      builder: () => DiagnosticViewModel(1),
    );
    final secondSpec = ViewModelSpec<DiagnosticViewModel>(
      builder: () {
        secondBuilderCalls++;
        return DiagnosticViewModel(2);
      },
    );
    final first = binding.read(firstSpec);
    final messages = <String>[];
    debugPrint = (message, {wrapWidth}) {
      if (message != null) messages.add(message);
    };

    final collided = binding.read(secondSpec);

    expect(collided, same(first));
    expect(secondBuilderCalls, 0);
    expect(messages, contains(contains('Different factory sources')));
    expect(messages, contains(contains('explicit, distinct key')));
    binding.dispose();
  });

  test('recreated instances of one factory class do not emit false warnings',
      () {
    final binding = ViewModelBinding();
    final messages = <String>[];
    debugPrint = (message, {wrapWidth}) {
      if (message != null) messages.add(message);
    };

    final first = binding.read(const DiagnosticFactory());
    final second = binding.read(const DiagnosticFactory());

    expect(second, same(first));
    expect(messages, isNot(contains(contains('Different factory sources'))));
    binding.dispose();
  });

  test('a failed builder does not pollute factory collision diagnostics', () {
    final binding = ViewModelBinding();
    expect(
      () => binding.read(
        ViewModelSpec<DiagnosticViewModel>(
          builder: () => throw StateError('expected builder failure'),
        ),
      ),
      throwsStateError,
    );
    final messages = <String>[];
    debugPrint = (message, {wrapWidth}) {
      if (message != null) messages.add(message);
    };

    binding.read(
      ViewModelSpec<DiagnosticViewModel>(
        builder: () => DiagnosticViewModel(2),
      ),
    );

    expect(messages, isNot(contains(contains('Different factory sources'))));
    binding.dispose();
  });

  test('watch bookkeeping uses ViewModel identity rather than equality', () {
    final binding = _CountingBinding();
    final first = binding.watch(
      ViewModelSpec<AlwaysEqualViewModel>(
        builder: AlwaysEqualViewModel.new,
        key: 'equal-vm-1',
      ),
    );
    final second = binding.watch(
      ViewModelSpec<AlwaysEqualViewModel>(
        builder: AlwaysEqualViewModel.new,
        key: 'equal-vm-2',
      ),
    );

    first.notifyListeners();
    second.notifyListeners();

    expect(binding.updates, 2);
    binding.dispose();
  });

  test('owners use binding identity and preserve the living primary owner', () {
    final first = _AlwaysEqualBinding();
    final second = _AlwaysEqualBinding();
    addTearDown(first.dispose);
    addTearDown(second.dispose);

    expect(first.viewModel.refHandler.primaryOwner, same(first));
    expect(second.viewModel, same(first.viewModel));
    final owners = first.viewModel.refHandler.owners;
    expect(owners, hasLength(2));
    expect(owners[0], same(first));
    expect(owners[1], same(second));
    expect(first.viewModel.owner, same(first));

    second.dispose();

    expect(first.viewModel.refHandler.owners, hasLength(1));
    expect(first.viewModel.refHandler.primaryOwner, same(first));
    expect(first.viewModel.owner, same(first));
    expect(first.viewModel.dependency.value, 42);
  });

  test('diagnostic listeners cannot interrupt owner attach or detach', () {
    final reportedErrors = <Object>[];
    ViewModel.initialize(
      config: ViewModelConfig(
        onError: (error, stack, type) => reportedErrors.add(error),
      ),
    );
    final first = _AlwaysEqualBinding();
    final second = _AlwaysEqualBinding();
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    final viewModel = first.viewModel;

    late VoidCallback removeSelfRemovingTrackerListener;
    removeSelfRemovingTrackerListener = DevToolTracker.instance.addListener(() {
      final hasTwoOwners = DevToolTracker
          .instance.dependencyGraph.viewModelInfos.values
          .any((info) => info.owners.length == 2);
      if (hasTwoOwners) {
        removeSelfRemovingTrackerListener();
      }
    });
    final removeThrowingTrackerListener =
        DevToolTracker.instance.addListener(() {
      throw StateError('tracker diagnostic failure');
    });
    final removeThrowingOwnerListener =
        viewModel.refHandler.addOwnerChangeListener((_, __, ___) {
      throw StateError('owner diagnostic failure');
    });

    expect(() => second.viewModel, returnsNormally);
    expect(viewModel.refHandler.owners, hasLength(2));

    expect(second.dispose, returnsNormally);

    expect(viewModel.refHandler.owners, hasLength(1));
    expect(viewModel.refHandler.primaryOwner, same(first));
    final handle = instanceManager.getNotifier<_OwnerViewModel>(
      factory: InstanceFactory(
        arg: const InstanceArg(key: 'equal-binding-shared-owner'),
      ),
    );
    expect(handle.bindingIds, [first.id]);
    expect(reportedErrors, isNotEmpty);

    removeSelfRemovingTrackerListener();
    removeThrowingTrackerListener();
    removeThrowingOwnerListener();
  });

  test('reset disposes retained instances and restores tracking', () {
    final binding = ViewModelBinding();
    final retained = binding.read(
      ViewModelSpec(
        builder: () => DiagnosticViewModel(1),
        key: 'retained',
        aliveForever: true,
      ),
    );
    binding.dispose();
    expect(retained.isDisposed, isFalse);
    expect(instanceManager.debugStoreCount, greaterThan(0));

    ViewModel.reset();

    expect(retained.isDisposed, isTrue);
    expect(instanceManager.debugStoreCount, 0);
    expect(DevToolTracker.instance.dependencyGraph.viewModelInfos, isEmpty);

    final nextBinding = ViewModelBinding();
    nextBinding.read(
      ViewModelSpec(
        builder: () => DiagnosticViewModel(2),
        key: 'tracked-after-reset',
      ),
    );
    expect(
      DevToolTracker.instance.dependencyGraph.viewModelInfos,
      isNotEmpty,
    );
    nextBinding.dispose();
  });

  test('reset blocks reentrant instance creation', () {
    final binding = ViewModelBinding();
    final retained = binding.read(
      ViewModelSpec<ReentrantDisposeViewModel>(
        builder: () => ReentrantDisposeViewModel(binding),
        key: 'reset-reentrant',
        aliveForever: true,
      ),
    );

    ViewModel.reset();

    expect(retained.resolutionError, isA<ViewModelError>());
    expect(instanceManager.debugStoreCount, 0);
    binding.dispose();
  });

  test('reset inside a create builder disposes the detached instance', () {
    final binding = ViewModelBinding();
    addTearDown(binding.dispose);
    DiagnosticViewModel? created;

    expect(
      () => binding.read(
        ViewModelSpec<DiagnosticViewModel>(
          builder: () {
            ViewModel.reset();
            return created = DiagnosticViewModel(7);
          },
          key: 'reset-inside-create-builder',
        ),
      ),
      throwsA(
        isA<ViewModelError>()
            .having(
              (error) => error.toString(),
              'message',
              contains('Store was disposed while the factory builder'),
            )
            .having(
              (error) => error.toString(),
              'cleanup',
              contains('disposed and was not cached'),
            ),
      ),
    );

    expect(created, isNotNull);
    expect(created!.isDisposed, isTrue);
    expect(instanceManager.debugStoreCount, 0);
  });

  test('reset inside a recreate builder disposes its detached replacement', () {
    final binding = ViewModelBinding();
    addTearDown(binding.dispose);
    final spec = ViewModelSpec<DiagnosticViewModel>(
      builder: () => DiagnosticViewModel(1),
      key: 'reset-inside-recreate-builder',
    );
    final original = binding.read(spec);
    DiagnosticViewModel? replacement;

    expect(
      () => binding.recreate(
        original,
        builder: () {
          ViewModel.reset();
          return replacement = DiagnosticViewModel(2);
        },
      ),
      throwsA(
        isA<ViewModelError>()
            .having(
              (error) => error.toString(),
              'message',
              contains('handle was disposed or replaced while the builder'),
            )
            .having(
              (error) => error.toString(),
              'cleanup',
              contains('detached replacement was disposed'),
            ),
      ),
    );

    expect(original.isDisposed, isTrue);
    expect(replacement, isNotNull);
    expect(replacement!.isDisposed, isTrue);
    expect(instanceManager.debugStoreCount, 0);
  });
}

class _CountingBinding with ViewModelBinding {
  int updates = 0;

  @override
  void onUpdate() {
    super.onUpdate();
    updates++;
  }
}
