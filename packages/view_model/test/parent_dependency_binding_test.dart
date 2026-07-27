import 'package:flutter_test/flutter_test.dart';
import 'package:view_model/src/view_model/state_store.dart';
import 'package:view_model/view_model.dart';

class _ChildViewModel with ViewModel {
  final List<String> boundIds = [];
  final List<String> unboundIds = [];

  void emit() => notifyListeners();

  @override
  void onBind(InstanceArg arg, String bindingId) {
    super.onBind(arg, bindingId);
    boundIds.add(bindingId);
  }

  @override
  void onUnbind(InstanceArg arg, String bindingId) {
    super.onUnbind(arg, bindingId);
    unboundIds.add(bindingId);
  }
}

final _childSpec = ViewModelSpec<_ChildViewModel>(
  builder: _ChildViewModel.new,
);

final _sharedChildSpec = ViewModelSpec<_ChildViewModel>(
  builder: _ChildViewModel.new,
  key: 'parent-dependency-shared-child',
);

const _taggedChildrenTag = 'parent-dependency-tagged-children';

final _taggedChildASpec = ViewModelSpec<_ChildViewModel>(
  builder: _ChildViewModel.new,
  key: 'parent-dependency-tagged-child-a',
  tag: _taggedChildrenTag,
);

final _taggedChildBSpec = ViewModelSpec<_ChildViewModel>(
  builder: _ChildViewModel.new,
  key: 'parent-dependency-tagged-child-b',
  tag: _taggedChildrenTag,
);

final _aliveUnkeyedChildSpec = ViewModelSpec<_ChildViewModel>(
  builder: _ChildViewModel.new,
  aliveForever: true,
);

final _aliveKeyedChildSpec = ViewModelSpec<_ChildViewModel>(
  builder: _ChildViewModel.new,
  key: 'parent-dependency-alive-child',
  aliveForever: true,
);

class _ParentViewModel with ViewModel {
  int dependencyNotifications = 0;
  int listenCallbacks = 0;

  _ChildViewModel get child => viewModelBinding.read(_childSpec);

  _ChildViewModel get watchedChild => viewModelBinding.watch(_childSpec);

  _ChildViewModel get sharedChild => viewModelBinding.read(_sharedChildSpec);

  _ChildViewModel get cachedSharedChild =>
      viewModelBinding.readCached(key: 'parent-dependency-shared-child');

  _ChildViewModel get watchedCachedSharedChild =>
      viewModelBinding.watchCached(key: 'parent-dependency-shared-child');

  List<_ChildViewModel> get taggedChildren =>
      viewModelBinding.readCachesByTag(_taggedChildrenTag);

  void listenToChild() {
    viewModelBinding.listen(
      _childSpec,
      onChanged: () => listenCallbacks++,
    );
  }

  _ChildViewModel get aliveUnkeyedChild =>
      viewModelBinding.read(_aliveUnkeyedChildSpec);

  _ChildViewModel get aliveKeyedChild =>
      viewModelBinding.read(_aliveKeyedChildSpec);

  @override
  void onDependencyNotify(ViewModel vm) {
    super.onDependencyNotify(vm);
    dependencyNotifications++;
  }
}

final _parentSpec = ViewModelSpec<_ParentViewModel>(
  builder: _ParentViewModel.new,
  key: 'parent-dependency-shared-parent',
);

final _aliveParentSpec = ViewModelSpec<_ParentViewModel>(
  builder: _ParentViewModel.new,
  key: 'parent-dependency-alive-parent',
  aliveForever: true,
);

class _CountingBinding with ViewModelBinding {
  int updates = 0;

  @override
  void onUpdate() {
    super.onUpdate();
    updates++;
  }
}

final _diamondLeafSpec = ViewModelSpec<_ChildViewModel>(
  builder: _ChildViewModel.new,
  key: 'parent-dependency-diamond-leaf',
);

class _DiamondBranchViewModel with ViewModel {
  int dependencyNotifications = 0;

  _ChildViewModel get leaf => viewModelBinding.watch(_diamondLeafSpec);

  @override
  void onDependencyNotify(ViewModel vm) {
    super.onDependencyNotify(vm);
    dependencyNotifications++;
  }
}

final _leftBranchSpec = ViewModelSpec<_DiamondBranchViewModel>(
  builder: _DiamondBranchViewModel.new,
  key: 'parent-dependency-left-branch',
);

final _rightBranchSpec = ViewModelSpec<_DiamondBranchViewModel>(
  builder: _DiamondBranchViewModel.new,
  key: 'parent-dependency-right-branch',
);

class _DiamondRootViewModel with ViewModel {
  int dependencyNotifications = 0;

  _DiamondBranchViewModel get left => viewModelBinding.watch(_leftBranchSpec);

  _DiamondBranchViewModel get right => viewModelBinding.watch(_rightBranchSpec);

  @override
  void onDependencyNotify(ViewModel vm) {
    super.onDependencyNotify(vm);
    dependencyNotifications++;
  }
}

final _diamondRootSpec = ViewModelSpec<_DiamondRootViewModel>(
  builder: _DiamondRootViewModel.new,
  key: 'parent-dependency-diamond-root',
);

void main() {
  setUp(ViewModel.reset);
  tearDown(ViewModel.reset);

  test('shared parent propagates owner additions and removals to child', () {
    final ownerA = ViewModelBinding();
    final parent = ownerA.read(_parentSpec);
    final child = parent.child;
    final dependencyBindingId = child.boundIds.singleWhere(
      (id) => id != ownerA.id,
    );

    expect(child.refHandler.owners, contains(ownerA));
    expect(
        child.boundIds, containsAll(<String>[dependencyBindingId, ownerA.id]));

    final ownerB = ViewModelBinding();
    expect(ownerB.read(_parentSpec), same(parent));

    // Child 已经创建后加入的 owner 也必须实时传播。
    expect(child.refHandler.owners, contains(ownerB));
    expect(child.boundIds, contains(ownerB.id));
    expect(parent.child, same(child));

    ownerA.dispose();

    expect(parent.isDisposed, isFalse);
    expect(child.isDisposed, isFalse);
    expect(parent.child, same(child));
    expect(child.refHandler.owners, isNot(contains(ownerA)));
    expect(child.refHandler.owners, contains(ownerB));
    expect(child.unboundIds, contains(ownerA.id));

    ownerB.dispose();

    expect(parent.isDisposed, isTrue);
    expect(child.isDisposed, isTrue);
    expect(
      child.unboundIds.toSet(),
      <String>{dependencyBindingId, ownerA.id, ownerB.id},
    );
  });

  test('direct and parent ownership from one binding are released separately',
      () {
    final owner = ViewModelBinding();
    final directChild = owner.read(_sharedChildSpec);
    final parent = owner.read(_parentSpec);

    expect(parent.sharedChild, same(directChild));
    expect(
      directChild.boundIds.where((id) => id == owner.id),
      hasLength(1),
    );

    // recycle parent 会释放 dependency edge，但不能误删 direct owner。
    owner.recycle(parent);

    expect(parent.isDisposed, isTrue);
    expect(directChild.isDisposed, isFalse);
    expect(directChild.unboundIds, isNot(contains(owner.id)));
    expect(owner.read(_sharedChildSpec), same(directChild));

    owner.dispose();
    expect(directChild.isDisposed, isTrue);
  });

  test('a root can globally recycle a child owned only through its parent', () {
    final owner = _CountingBinding();
    final parent = owner.watch(_parentSpec);
    final child = parent.child;
    final ViewModel childAsBase = child;
    owner.updates = 0;

    owner.recycle(childAsBase);

    expect(child.isDisposed, isTrue);
    expect(parent.dependencyNotifications, 1);
    expect(owner.updates, 1);
    expect(parent.child, isNot(same(child)));

    owner.dispose();
  });

  test('recycling a parent creates new parent and private child generations',
      () {
    final owner = _CountingBinding();
    final parent = owner.watch(_parentSpec);
    final child = parent.child;
    final dependencyBindingId = child.boundIds.singleWhere(
      (id) => id != owner.id,
    );
    owner.updates = 0;

    owner.recycle(parent);

    expect(parent.isDisposed, isTrue);
    expect(child.isDisposed, isTrue);
    expect(owner.updates, 1);
    expect(() => parent.child, throwsA(isA<ViewModelError>()));

    final nextParent = owner.watch(_parentSpec);
    final nextChild = nextParent.child;
    final nextDependencyBindingId = nextChild.boundIds.singleWhere(
      (id) => id != owner.id,
    );

    expect(nextParent, isNot(same(parent)));
    expect(nextChild, isNot(same(child)));
    expect(nextDependencyBindingId, isNot(dependencyBindingId));
    expect(owner.watch(_parentSpec), same(nextParent));
    expect(nextParent.child, same(nextChild));

    owner.dispose();
    expect(nextParent.isDisposed, isTrue);
    expect(nextChild.isDisposed, isTrue);
  });

  test('cached and tag batch APIs establish the same parent ownership', () {
    final creator = ViewModelBinding();
    final shared = creator.read(_sharedChildSpec);
    final taggedA = creator.read(_taggedChildASpec);
    final taggedB = creator.read(_taggedChildBSpec);
    final owner = ViewModelBinding();
    final parent = owner.read(_parentSpec);

    expect(parent.cachedSharedChild, same(shared));
    expect(parent.taggedChildren,
        containsAll(<_ChildViewModel>[taggedA, taggedB]));

    creator.dispose();

    expect(shared.isDisposed, isFalse);
    expect(taggedA.isDisposed, isFalse);
    expect(taggedB.isDisposed, isFalse);
    expect(shared.refHandler.owners, contains(owner));
    expect(taggedA.refHandler.owners, contains(owner));
    expect(taggedB.refHandler.owners, contains(owner));

    owner.dispose();

    expect(shared.isDisposed, isTrue);
    expect(taggedA.isDisposed, isTrue);
    expect(taggedB.isDisposed, isTrue);
  });

  test('watchCached bubbles through the parent once', () {
    final creator = ViewModelBinding();
    final child = creator.read(_sharedChildSpec);
    final owner = _CountingBinding();
    final parent = owner.watch(_parentSpec);

    expect(parent.watchedCachedSharedChild, same(child));
    creator.dispose();
    owner.updates = 0;

    child.emit();

    expect(parent.dependencyNotifications, 1);
    expect(owner.updates, 1);

    owner.dispose();
  });

  test('read does not bubble while watch bubbles once', () {
    final owner = _CountingBinding();
    final parent = owner.watch(_parentSpec);
    final child = parent.child;

    owner.updates = 0;
    child.emit();

    expect(parent.dependencyNotifications, 0);
    expect(owner.updates, 0);

    expect(parent.watchedChild, same(child));
    child.emit();

    expect(parent.dependencyNotifications, 1);
    expect(owner.updates, 1);

    owner.dispose();
  });

  test('shared parent owns one watch and listen subscription for all roots',
      () {
    final ownerA = _CountingBinding();
    final parent = ownerA.watch(_parentSpec);
    final child = parent.watchedChild;
    parent.listenToChild();
    final ownerB = _CountingBinding();

    expect(ownerB.watch(_parentSpec), same(parent));
    ownerA.updates = 0;
    ownerB.updates = 0;

    child.emit();

    expect(parent.dependencyNotifications, 1);
    expect(parent.listenCallbacks, 1);
    expect(ownerA.updates, 1);
    expect(ownerB.updates, 1);

    ownerA.dispose();
    ownerB.dispose();
  });

  test('diamond propagation updates each binding once per transaction', () {
    final owner = _CountingBinding();
    final root = owner.watch(_diamondRootSpec);
    final left = root.left;
    final right = root.right;
    final leaf = left.leaf;

    expect(right.leaf, same(leaf));
    // The root also watches D directly; it must still update only once.
    expect(owner.watch(_diamondLeafSpec), same(leaf));
    owner.updates = 0;

    leaf.emit();

    expect(left.dependencyNotifications, 1);
    expect(right.dependencyNotifications, 1);
    expect(root.dependencyNotifications, 1);
    expect(owner.updates, 1);

    owner.dispose();
  });

  test('a microtask notification starts a fresh propagation transaction',
      () async {
    final owner = _CountingBinding();
    final parent = owner.watch(_parentSpec);
    final child = parent.watchedChild;
    var scheduleAgain = true;
    child.listen(onChanged: () {
      if (!scheduleAgain) return;
      scheduleAgain = false;
      Future.microtask(child.emit);
    });

    child.emit();
    await Future<void>.delayed(Duration.zero);

    expect(parent.dependencyNotifications, 2);
    expect(owner.updates, 2);

    owner.dispose();
  });

  test('nested aliveForever also requires an explicit key', () {
    final owner = ViewModelBinding();
    final parent = owner.read(_parentSpec);

    expect(
      () => parent.aliveUnkeyedChild,
      throwsA(isA<ViewModelError>()),
    );

    final child = parent.aliveKeyedChild;
    owner.dispose();

    expect(parent.isDisposed, isTrue);
    expect(child.isDisposed, isFalse);

    final nextOwner = ViewModelBinding();
    expect(nextOwner.read(_aliveKeyedChildSpec), same(child));
    nextOwner.recycle(child);
    expect(child.isDisposed, isTrue);
    nextOwner.dispose();
  });

  test('aliveForever parent transitively keeps its private child alive', () {
    final owner = ViewModelBinding();
    final parent = owner.read(_aliveParentSpec);
    final child = parent.child;

    owner.dispose();

    expect(parent.isDisposed, isFalse);
    expect(child.isDisposed, isFalse);
    expect(parent.refHandler.externalOwners, isEmpty);
    expect(child.refHandler.externalOwners, isEmpty);

    final nextOwner = ViewModelBinding();
    expect(nextOwner.read(_aliveParentSpec), same(parent));
    expect(parent.child, same(child));
    expect(child.refHandler.externalOwners, contains(nextOwner));

    nextOwner.recycle(parent);
    expect(parent.isDisposed, isTrue);
    expect(child.isDisposed, isTrue);
    nextOwner.dispose();
  });
}
