import 'package:flutter_test/flutter_test.dart';
import 'package:view_model/src/view_model/state_store.dart';
import 'package:view_model/src/view_model/view_model_binding.dart'
    show ViewModelDependencyBinding;
import 'package:view_model/view_model.dart';

class _SelfRecursiveViewModel with ViewModel {
  _SelfRecursiveViewModel() {
    viewModelBinding.read(_selfRecursiveSpec);
  }
}

final _selfRecursiveSpec = ViewModelSpec<_SelfRecursiveViewModel>(
  builder: _SelfRecursiveViewModel.new,
);

class _KeyedSelfRecursiveViewModel with ViewModel {
  _KeyedSelfRecursiveViewModel() {
    viewModelBinding.read(_keyedSelfRecursiveSpec);
  }
}

final _keyedSelfRecursiveSpec = ViewModelSpec<_KeyedSelfRecursiveViewModel>(
  builder: _KeyedSelfRecursiveViewModel.new,
  key: 'keyed-self-recursive',
);

class _OnCreateRecursiveViewModel with ViewModel {
  @override
  void onCreate(InstanceArg arg) {
    super.onCreate(arg);
    viewModelBinding.read(_onCreateRecursiveSpec);
  }
}

final _onCreateRecursiveSpec = ViewModelSpec<_OnCreateRecursiveViewModel>(
  builder: _OnCreateRecursiveViewModel.new,
);

class _IndirectAViewModel with ViewModel {
  _IndirectAViewModel() {
    viewModelBinding.read(_indirectBSpec);
  }
}

class _IndirectBViewModel with ViewModel {
  _IndirectBViewModel() {
    viewModelBinding.read(_indirectASpec);
  }
}

final _indirectASpec = ViewModelSpec<_IndirectAViewModel>(
  builder: _IndirectAViewModel.new,
);

final _indirectBSpec = ViewModelSpec<_IndirectBViewModel>(
  builder: _IndirectBViewModel.new,
);

class _RollbackChildViewModel with ViewModel {
  _RollbackChildViewModel() {
    created++;
  }

  static int created = 0;
  static int disposed = 0;

  @override
  void dispose() {
    disposed++;
    super.dispose();
  }
}

final _rollbackChildSpec = ViewModelSpec<_RollbackChildViewModel>(
  builder: _RollbackChildViewModel.new,
);

class _ThrowingParentViewModel with ViewModel {
  _ThrowingParentViewModel() {
    viewModelBinding.read(_rollbackChildSpec);
    throw StateError('parent construction failed');
  }
}

final _throwingParentSpec = ViewModelSpec<_ThrowingParentViewModel>(
  builder: _ThrowingParentViewModel.new,
  key: 'throwing-parent',
);

class _AtomicParentViewModel with ViewModel {
  _RollbackChildViewModel get child =>
      viewModelBinding.read(_rollbackChildSpec);
}

final _atomicParentSpec = ViewModelSpec<_AtomicParentViewModel>(
  builder: _AtomicParentViewModel.new,
  key: 'atomic-parent',
);

class _RuntimeCycleAViewModel with ViewModel {
  _RuntimeCycleBViewModel get dependency =>
      viewModelBinding.read(_runtimeCycleBSpec);
}

class _RuntimeCycleBViewModel with ViewModel {
  _RuntimeCycleAViewModel get dependency =>
      viewModelBinding.read(_runtimeCycleASpec);
}

final _runtimeCycleASpec = ViewModelSpec<_RuntimeCycleAViewModel>(
  builder: _RuntimeCycleAViewModel.new,
  key: 'runtime-cycle-a',
);

final _runtimeCycleBSpec = ViewModelSpec<_RuntimeCycleBViewModel>(
  builder: _RuntimeCycleBViewModel.new,
  key: 'runtime-cycle-b',
);

class _LongCycleAViewModel with ViewModel {
  _LongCycleBViewModel get dependency => viewModelBinding.read(_longCycleBSpec);
}

class _LongCycleBViewModel with ViewModel {
  _LongCycleCViewModel get dependency => viewModelBinding.read(_longCycleCSpec);
}

class _LongCycleCViewModel with ViewModel {
  _LongCycleAViewModel get dependency => viewModelBinding.read(_longCycleASpec);
}

final _longCycleASpec = ViewModelSpec<_LongCycleAViewModel>(
  builder: _LongCycleAViewModel.new,
  key: 'long-runtime-cycle-a',
);

final _longCycleBSpec = ViewModelSpec<_LongCycleBViewModel>(
  builder: _LongCycleBViewModel.new,
  key: 'long-runtime-cycle-b',
);

final _longCycleCSpec = ViewModelSpec<_LongCycleCViewModel>(
  builder: _LongCycleCViewModel.new,
  key: 'long-runtime-cycle-c',
);

class _DependencyUpdateParentViewModel with ViewModel {
  void invokeGenericBindingUpdate() {
    final binding = viewModelBinding as ViewModelDependencyBinding;
    // ignore: invalid_use_of_protected_member
    binding.onUpdate();
  }
}

final _dependencyUpdateParentSpec =
    ViewModelSpec<_DependencyUpdateParentViewModel>(
  builder: _DependencyUpdateParentViewModel.new,
  key: 'dependency-update-parent',
);

class _ThrowingIdBinding extends ViewModelBinding {
  bool throwOnId = false;

  @override
  String get id {
    if (throwOnId) throw StateError('binding id failure');
    return super.id;
  }
}

void main() {
  setUp(() {
    ViewModel.reset();
    _RollbackChildViewModel.created = 0;
    _RollbackChildViewModel.disposed = 0;
  });
  tearDown(ViewModel.reset);

  test('unkeyed self recursion fails with a construction lineage error', () {
    final owner = ViewModelBinding();

    expect(
      () => owner.read(_selfRecursiveSpec),
      throwsA(
        isA<ViewModelError>().having(
          (error) => error.toString(),
          'message',
          contains('Circular ViewModel construction'),
        ),
      ),
    );

    owner.dispose();
  });

  test('unkeyed indirect recursion fails without overflowing the stack', () {
    final owner = ViewModelBinding();

    expect(
      () => owner.read(_indirectASpec),
      throwsA(
        isA<ViewModelError>().having(
          (error) => error.toString(),
          'message',
          allOf(
              contains('_IndirectAViewModel'), contains('_IndirectBViewModel')),
        ),
      ),
    );

    owner.dispose();
  });

  test('keyed self recursion compares the explicit construction key', () {
    final owner = ViewModelBinding();

    expect(
      () => owner.read(_keyedSelfRecursiveSpec),
      throwsA(
        isA<ViewModelError>().having(
          (error) => error.toString(),
          'message',
          allOf(
            contains('Circular ViewModel construction'),
            contains('keyed-self-recursive'),
          ),
        ),
      ),
    );

    owner.dispose();
  });

  test('onCreate cycle follows onError and keeps the existing lifecycle policy',
      () {
    final errors = <Object>[];
    ViewModel.initialize(
      config: ViewModelConfig(
        onError: (error, stackTrace, type) => errors.add(error),
      ),
    );
    final owner = ViewModelBinding();

    final viewModel = owner.read(_onCreateRecursiveSpec);

    expect(viewModel.isDisposed, isFalse);
    expect(
      errors,
      contains(
        isA<ViewModelError>().having(
          (error) => error.toString(),
          'message',
          contains('Circular ViewModel construction'),
        ),
      ),
    );

    owner.dispose();
    expect(viewModel.isDisposed, isTrue);
  });

  test('failed builder rolls back children created by its dependency scope',
      () {
    final owner = ViewModelBinding();

    expect(
      () => owner.read(_throwingParentSpec),
      throwsA(isA<StateError>()),
    );
    expect(_RollbackChildViewModel.created, 1);
    expect(_RollbackChildViewModel.disposed, 1);

    owner.dispose();
  });

  test('runtime indirect ownership cycle is rejected atomically', () {
    final owner = ViewModelBinding();
    final a = owner.read(_runtimeCycleASpec);
    final b = owner.read(_runtimeCycleBSpec);

    expect(a.dependency, same(b));
    expect(
      () => b.dependency,
      throwsA(
        isA<ViewModelError>().having(
          (error) => error.toString(),
          'message',
          contains('Circular ViewModel dependency'),
        ),
      ),
    );

    expect(a.isDisposed, isFalse);
    expect(b.isDisposed, isFalse);
    owner.dispose();
    expect(a.isDisposed, isTrue);
    expect(b.isDisposed, isTrue);
  });

  test('runtime cycle detection traverses multiple dependency bindings', () {
    final owner = ViewModelBinding();
    final a = owner.read(_longCycleASpec);
    final b = owner.read(_longCycleBSpec);
    final c = owner.read(_longCycleCSpec);

    expect(a.dependency, same(b));
    expect(b.dependency, same(c));
    expect(
      () => c.dependency,
      throwsA(
        isA<ViewModelError>().having(
          (error) => error.toString(),
          'message',
          contains('Circular ViewModel dependency'),
        ),
      ),
    );

    owner.dispose();
    expect(a.isDisposed, isTrue);
    expect(b.isDisposed, isTrue);
    expect(c.isDisposed, isTrue);
  });

  test('generic dependency binding updates remain a no-op', () {
    final owner = ViewModelBinding();
    final parent = owner.read(_dependencyUpdateParentSpec);

    expect(parent.invokeGenericBindingUpdate, returnsNormally);
    expect(parent.isDisposed, isFalse);

    owner.dispose();
    expect(parent.isDisposed, isTrue);
  });

  test('recycle prevents the disposed parent from resolving dependencies', () {
    final owner = ViewModelBinding();
    final parent = owner.read(_atomicParentSpec);
    parent.child;

    owner.recycle(parent);

    expect(parent.isDisposed, isTrue);
    expect(
      () => parent.child,
      throwsA(
        isA<ViewModelError>().having(
          (error) => error.toString(),
          'message',
          contains('Cannot resolve dependencies from a disposed'),
        ),
      ),
    );

    owner.dispose();
  });

  test('dependency binding dispose errors use the dispose error channel', () {
    final reportedErrors = <(Object, ErrorType)>[];
    ViewModel.initialize(
      config: ViewModelConfig(
        onError: (error, stackTrace, type) {
          reportedErrors.add((error, type));
        },
      ),
    );
    final owner = _ThrowingIdBinding();
    final parent = owner.read(_atomicParentSpec);
    final child = parent.child;
    expect(child.isDisposed, isFalse);

    owner.throwOnId = true;
    owner.recycle(parent);
    owner.throwOnId = false;

    expect(parent.isDisposed, isTrue);
    expect(
      reportedErrors.any(
        (entry) => entry.$1 is StateError && entry.$2 == ErrorType.dispose,
      ),
      isTrue,
    );

    owner.dispose();
  });
}
