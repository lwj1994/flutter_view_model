import 'package:flutter_test/flutter_test.dart';
import 'package:view_model/src/view_model/state_store.dart';
import 'package:view_model/view_model.dart';

class _SelfRecursiveViewModel with ViewModel {
  _SelfRecursiveViewModel() {
    viewModelBinding.read(_selfRecursiveSpec);
  }
}

final _selfRecursiveSpec = ViewModelSpec<_SelfRecursiveViewModel>(
  builder: _SelfRecursiveViewModel.new,
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
  _AtomicParentViewModel({bool fail = false}) {
    if (fail) {
      viewModelBinding.read(_rollbackChildSpec);
      throw StateError('replacement construction failed');
    }
  }

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

  test('failed recreate preserves old parent and dependency scope', () {
    final owner = ViewModelBinding();
    final parent = owner.read(_atomicParentSpec);
    final child = parent.child;

    expect(
      () => owner.recreate(
        parent,
        builder: () => _AtomicParentViewModel(fail: true),
      ),
      throwsA(isA<StateError>()),
    );

    expect(owner.read(_atomicParentSpec), same(parent));
    expect(parent.isDisposed, isFalse);
    expect(parent.child, same(child));
    expect(child.isDisposed, isFalse);
    expect(_RollbackChildViewModel.created, 2);
    expect(_RollbackChildViewModel.disposed, 1);

    owner.dispose();
    expect(_RollbackChildViewModel.disposed, 2);
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
}
