import 'package:flutter_test/flutter_test.dart';
import 'package:view_model/src/get_instance/manager.dart';
import 'package:view_model/src/get_instance/store.dart';
import 'package:view_model/src/view_model/state_store.dart';
import 'package:view_model/view_model.dart';

typedef _BindingHook = void Function(_Node, String);

class _Node with ViewModel {
  _Node(this.name, this.events,
      {void Function(_Node)? construct,
      this.created,
      this.bound,
      this.unbound}) {
    addDispose(() => events.add('cleanup:$name'));
    construct?.call(this);
  }

  final String name;
  final List<String> events;
  final void Function(_Node)? created;
  final _BindingHook? bound;
  final _BindingHook? unbound;

  _Node child(ViewModelFactory<_Node> spec, {bool watch = false}) =>
      watch ? viewModelBinding.watch(spec) : viewModelBinding.read(spec);

  void releaseChild(ViewModelFactory<_Node> spec) {
    (viewModelBinding as ViewModelBinding).unbind(child(spec));
  }

  List<_Node> batch(Object tag, {bool watch = false}) => watch
      ? viewModelBinding.watchCachesByTag<_Node>(tag)
      : viewModelBinding.readCachesByTag<_Node>(tag);

  @override
  void onCreate(InstanceArg arg) {
    super.onCreate(arg);
    events.add('create:$name');
    created?.call(this);
  }

  @override
  void onBind(InstanceArg arg, String bindingId) {
    super.onBind(arg, bindingId);
    events.add('bind:$name:$bindingId');
    bound?.call(this, bindingId);
  }

  @override
  void onUnbind(InstanceArg arg, String bindingId) {
    super.onUnbind(arg, bindingId);
    events.add('unbind:$name:$bindingId');
    unbound?.call(this, bindingId);
  }

  @override
  void onDispose(InstanceArg arg) {
    events.add('dispose:$name');
    super.onDispose(arg);
  }
}

class _Owner extends ViewModelBinding {
  _Owner(this.spec);
  final ViewModelFactory<_Node> spec;
  _Node get vm => read(spec);
  _Node get watched => watch(spec);
  int updates = 0;
  void Function()? refreshed;

  @override
  void onUpdate() {
    super.onUpdate();
    updates++;
    refreshed?.call();
  }
}

InstanceHandle<_Node> _handle(String key) => instanceManager.getNotifier<_Node>(
      factory: InstanceFactory(arg: InstanceArg(key: key)),
    );

void main() {
  final events = <String>[];
  final errors = <Object>[];
  setUp(() {
    ViewModel.reset();
    events.clear();
    errors.clear();
    ViewModel.initialize(
        config: ViewModelConfig(
      onError: (error, _, __) => errors.add(error),
    ));
  });
  tearDown(() {
    ViewModel.reset();
    expect(errors, isEmpty, reason: 'Lifecycle errors must not hide failures.');
  });

  test('lifecycle callbacks see committed owners and reads preserve watch', () {
    final snapshots = <(String, List<String>, List<String>)>[];
    void snapshot(_Node vm, String phase) {
      snapshots.add((
        phase,
        _handle('node').bindingIds,
        vm.refHandler.owners.map((owner) => owner.id).toList()
      ));
    }

    final owner = _Owner(ViewModelSpec(
      builder: () => _Node('node', events,
          bound: (vm, _) => snapshot(vm, 'bind'),
          unbound: (vm, _) => snapshot(vm, 'unbind')),
      key: 'node',
    ));
    addTearDown(owner.dispose);

    owner.vm;
    owner.watched;
    owner.watched;
    owner.vm.notifyListeners();
    expect(owner.updates, 1);
    owner.dispose();

    expect(snapshots.map((item) => item.$1), ['bind', 'unbind']);
    expect(snapshots.map((item) => item.$2), [
      [owner.id],
      <String>[]
    ]);
    expect(snapshots.map((item) => item.$3), [
      [owner.id],
      <String>[]
    ]);
    expect(events, [
      'create:node',
      'bind:node:${owner.id}',
      'unbind:node:${owner.id}',
      'dispose:node',
      'cleanup:node'
    ]);
  });

  test('onBind can read and watch the same generation reentrantly', () {
    late _Owner owner;
    var sameGeneration = false;
    owner = _Owner(ViewModelSpec(
      builder: () => _Node('node', events, bound: (vm, _) {
        sameGeneration = identical(owner.watched, vm);
      }),
      key: 'node',
    ));
    addTearDown(owner.dispose);
    owner.vm.notifyListeners();
    expect(sameGeneration, isTrue);
    expect(owner.updates, 1);
    expect(events, ['create:node', 'bind:node:${owner.id}']);
    expect(owner.vm.refHandler.owners, [owner]);
  });

  for (final phase in ['builder', 'create', 'bind']) {
    for (final retained in [false, true]) {
      test('owner disposed in $phase rolls back new retained=$retained handle',
          () {
        late _Owner owner;
        owner = _Owner(ViewModelSpec(
          builder: () {
            if (phase == 'builder') owner.dispose();
            return _Node('node', events, created: (_) {
              if (phase == 'create') owner.dispose();
            }, bound: (_, __) {
              if (phase == 'bind') owner.dispose();
            });
          },
          key: 'node',
          aliveForever: retained,
        ));
        addTearDown(owner.dispose);
        expect(() => owner.vm, throwsA(isA<ViewModelError>()));
        expect(owner.isDisposed, isTrue);
        expect(events.where((event) => event == 'dispose:node'), hasLength(1));
        expect(events.where((event) => event == 'cleanup:node'), hasLength(1));
        expect(ViewModel.maybeReadCached<_Node>(key: 'node'), isNull);
      });
    }
  }

  test('onBind disposal rolls back only the joining owner on a cache hit', () {
    late _Owner joining;
    final spec = ViewModelSpec<_Node>(
      builder: () => _Node('node', events, bound: (_, id) {
        if (id == joining.id) joining.dispose();
      }),
      key: 'node',
    );
    final keeper = _Owner(spec);
    joining = _Owner(spec);
    addTearDown(keeper.dispose);
    addTearDown(joining.dispose);
    keeper.watched;
    expect(() => joining.watched, throwsA(isA<ViewModelError>()));
    expect(keeper.vm.refHandler.owners, [keeper]);
    expect(_handle('node').bindingIds, [keeper.id]);
    keeper.vm.notifyListeners();
    expect(keeper.updates, 1);
    expect(joining.updates, 0);
    expect(events.where((event) => event == 'dispose:node'), isEmpty);
  });

  test('onUnbind can reacquire without losing the replacement registration',
      () {
    late _Owner owner;
    var rebind = true;
    final spec = ViewModelSpec<_Node>(
      builder: () => _Node('node', events, unbound: (_, id) {
        if (id == owner.id && rebind) {
          rebind = false;
          owner.watched;
        }
      }),
      key: 'node',
    );
    final keeper = _Owner(spec);
    owner = _Owner(spec);
    addTearDown(keeper.dispose);
    addTearDown(owner.dispose);
    keeper.vm;
    owner.watched;
    events.clear();
    owner.unbind(owner.vm);
    expect(events, ['unbind:node:${owner.id}', 'bind:node:${owner.id}']);
    expect(owner.vm.refHandler.owners, [keeper, owner]);
    owner.vm.notifyListeners();
    expect(owner.updates, 1);
    owner.dispose();
    expect(keeper.vm.refHandler.owners, [keeper]);
  });

  test('child onBind can remove a joining parent root during propagation', () {
    late _Owner joining;
    final parentSpec = ViewModelSpec<_Node>(
        builder: () => _Node('parent', events), key: 'parent');
    final childSpec = ViewModelSpec<_Node>(
        builder: () => _Node('child', events, bound: (_, id) {
              if (id == joining.id) joining.dispose();
            }),
        key: 'child');
    final siblingSpec = ViewModelSpec<_Node>(
        builder: () => _Node('sibling', events), key: 'sibling');
    final keeper = _Owner(parentSpec);
    joining = _Owner(parentSpec);
    addTearDown(keeper.dispose);
    addTearDown(joining.dispose);
    keeper.vm.child(childSpec);
    keeper.vm.child(siblingSpec);

    expect(() => joining.vm, throwsA(isA<ViewModelError>()));
    expect(keeper.vm.refHandler.externalOwners, [keeper]);
    for (final spec in [childSpec, siblingSpec]) {
      expect(keeper.vm.child(spec).refHandler.externalOwners, [keeper]);
    }
    expect(_handle('child').bindingIds, isNot(contains(joining.id)));
    expect(_handle('sibling').bindingIds, isNot(contains(joining.id)));
    keeper.dispose();
    expect(events.where((event) => event.startsWith('dispose:')), hasLength(3));
  });

  test('owner listeners never deliver an obsolete snapshot after reentry', () {
    final spec =
        ViewModelSpec<_Node>(builder: () => _Node('node', events), key: 'node');
    final keeper = _Owner(spec);
    final joining = _Owner(spec);
    addTearDown(keeper.dispose);
    addTearDown(joining.dispose);
    final snapshots = <List<String>>[];
    keeper.vm.refHandler.addOwnerChangeListener((owners, _, __) {
      if (owners.contains(joining.id)) joining.dispose();
    });
    keeper.vm.refHandler.addOwnerChangeListener((owners, _, __) {
      snapshots.add(owners);
    });
    expect(() => joining.vm, throwsA(isA<ViewModelError>()));
    expect(snapshots, [
      [keeper.id]
    ]);
    expect(keeper.vm.refHandler.owners, [keeper]);
  });

  test('cycle rejection has no lifecycle or owner-change side effects', () {
    final a =
        _Owner(ViewModelSpec(builder: () => _Node('a', events), key: 'a'));
    final b =
        _Owner(ViewModelSpec(builder: () => _Node('b', events), key: 'b'));
    addTearDown(a.dispose);
    addTearDown(b.dispose);
    a.watched.child(b.spec, watch: true);
    b.watched;
    final owners = _handle('a').bindingIds;
    var changes = 0;
    a.vm.refHandler.addOwnerChangeListener((_, __, ___) => changes++);
    events.clear();

    expect(() => b.vm.child(a.spec), throwsA(isA<ViewModelError>()));
    expect(events, isEmpty);
    expect(changes, 0);
    expect(_handle('a').bindingIds, owners);
    b.vm.notifyListeners();
    expect(a.updates, 1);
    expect(b.updates, 1);
  });

  test('onBind reentry sees the committed edge when checking a reverse cycle',
      () {
    late _Owner a;
    Object? rejected;
    final bSpec = ViewModelSpec<_Node>(
        builder: () => _Node('b', events, bound: (vm, id) {
              if (id != a.id) {
                try {
                  vm.child(a.spec);
                } catch (error) {
                  rejected = error;
                }
              }
            }),
        key: 'b');
    a = _Owner(ViewModelSpec(builder: () => _Node('a', events), key: 'a'));
    addTearDown(a.dispose);
    a.vm.child(bSpec);
    expect(rejected, isA<ViewModelError>());
    expect(a.vm.refHandler.owners, [a]);
    expect(a.vm.child(bSpec).refHandler.externalOwners, [a]);
  });

  for (final watch in [false, true]) {
    test('rejected tag batch watch=$watch preserves pre-existing child edges',
        () {
      final a = _Owner(ViewModelSpec(
          builder: () => _Node('a', events), key: 'a', tag: 'batch'));
      final b = _Owner(ViewModelSpec(
          builder: () => _Node('b', events), key: 'b', tag: 'batch'));
      final c = _Owner(ViewModelSpec(
          builder: () => _Node('c', events), key: 'c', tag: 'batch'));
      addTearDown(a.dispose);
      addTearDown(b.dispose);
      addTearDown(c.dispose);
      a.watched;
      b.vm;
      c.vm;
      a.vm.child(c.spec, watch: true);
      final bOwners = _handle('b').bindingIds;
      final cOwners = _handle('c').bindingIds;
      events.clear();

      // Creation order makes the invalid self edge the final batch member.
      expect(() => a.vm.batch('batch', watch: watch),
          throwsA(isA<ViewModelError>()));
      expect(events, isEmpty);
      expect(_handle('b').bindingIds, bOwners);
      expect(_handle('c').bindingIds, cOwners);
      c.vm.notifyListeners();
      expect(a.updates, 1);
      b.vm.notifyListeners();
      expect(a.updates, 1);
    });
  }

  test(
      'failed construction releases tentative edges but preserves shared watch',
      () {
    final child = _Owner(
        ViewModelSpec(builder: () => _Node('child', events), key: 'child'));
    final parent = _Owner(ViewModelSpec<_Node>(
        builder: () => _Node('failed', events, construct: (vm) {
              vm.child(child.spec, watch: true);
              throw StateError('constructor failed');
            }),
        key: 'failed'));
    addTearDown(child.dispose);
    addTearDown(parent.dispose);
    child.watched;
    expect(() => parent.vm, throwsStateError);
    expect(child.vm.refHandler.owners, [child]);
    expect(_handle('child').bindingIds, [child.id]);
    expect(events.where((event) => event == 'cleanup:failed'), hasLength(1));
    expect(ViewModel.maybeReadCached<_Node>(key: 'failed'), isNull);
    child.vm.notifyListeners();
    expect(child.updates, 1);
    expect(parent.updates, 0);
  });

  test('batch interrupted by recycle rolls back only newly acquired handles',
      () {
    late _Owner joining;
    final b = _Owner(ViewModelSpec(
        builder: () => _Node('b', events), key: 'b', tag: 'batch'));
    final aSpec = ViewModelSpec<_Node>(
        builder: () => _Node('a', events, bound: (_, id) {
              if (id == joining.id) b.recycle(b.vm);
            }),
        key: 'a',
        tag: 'batch');
    final a = _Owner(aSpec);
    joining = _Owner(ViewModelSpec(
        builder: () => _Node('existing', events), key: 'existing'));
    addTearDown(a.dispose);
    addTearDown(b.dispose);
    addTearDown(joining.dispose);
    b.vm;
    a.watched;
    joining.watched;

    expect(() => joining.readCachesByTag<_Node>('batch'),
        throwsA(isA<ViewModelError>()));
    expect(a.vm.refHandler.owners, [a]);
    expect(joining.vm.refHandler.owners, [joining]);
    a.vm.notifyListeners();
    joining.vm.notifyListeners();
    expect(a.updates, 1);
    expect(joining.updates, 1);
  });

  test(
      'recycle in onUnbind is idempotent and refresh resolves a new generation',
      () {
    late _Owner owner;
    owner = _Owner(ViewModelSpec(
        builder: () => _Node('node', events, unbound: (vm, _) {
              owner.recycle(vm);
            }),
        key: 'node'));
    addTearDown(owner.dispose);
    final previous = identityHashCode(owner.vm);
    owner.refreshed = () {
      owner.vm;
    };
    owner.recycle(owner.vm);
    expect(identityHashCode(owner.vm), isNot(previous));
    expect(owner.vm.isDisposed, isFalse);
    expect(owner.vm.refHandler.owners, [owner]);
    expect(events.where((event) => event == 'dispose:node'), hasLength(1));
    expect(events.where((event) => event.startsWith('unbind:')), hasLength(1));
    owner.refreshed = null;
  });

  test('reentrant child reattachment survives cleanup of the old parent edge',
      () {
    late _Owner parent;
    String? dependencyId;
    late ViewModelFactory<_Node> childSpec;
    var reattach = true;
    final child = _Owner(ViewModelSpec<_Node>(
        builder: () => _Node('child', events, unbound: (_, id) {
              if (id == dependencyId && reattach) {
                reattach = false;
                parent.vm.child(childSpec, watch: true);
              }
            }),
        key: 'child'));
    childSpec = child.spec;
    parent = _Owner(
        ViewModelSpec(builder: () => _Node('parent', events), key: 'parent'));
    addTearDown(child.dispose);
    addTearDown(parent.dispose);
    child.vm;
    parent.vm.child(child.spec, watch: true);
    dependencyId = child.vm.refHandler.owners
        .singleWhere((owner) => owner.isDependencyBinding)
        .id;
    events.clear();

    parent.vm.releaseChild(child.spec);
    expect(child.vm.refHandler.externalOwners, [child, parent]);
    expect(_handle('child').bindingIds, contains(dependencyId));
    expect(events, isNot(contains('unbind:child:${parent.id}')));
    parent.dispose();
    expect(child.vm.refHandler.owners, [child]);
  });

  test('recycle removes old cache before propagated unbind; refresh coalesces',
      () {
    late _Owner parent;
    var resolveInUnbind = true;
    final childSpec = ViewModelSpec<_Node>(
        builder: () => _Node('child', events, unbound: (_, id) {
              if (id == parent.id && resolveInUnbind) {
                resolveInUnbind = false;
                parent.watched.notifyListeners();
              }
            }),
        key: 'child');
    parent = _Owner(
        ViewModelSpec(builder: () => _Node('parent', events), key: 'parent'));
    addTearDown(parent.dispose);
    final previous = identityHashCode(parent.watched);
    parent.vm.child(childSpec);
    parent.recycle(parent.vm);

    expect(identityHashCode(parent.vm), isNot(previous));
    expect(parent.vm.isDisposed, isFalse);
    expect(parent.updates, 1);
    expect(events.where((event) => event == 'dispose:parent'), hasLength(1));
    expect(events.where((event) => event == 'dispose:child'), hasLength(1));
  });

  test('binding disposal tolerates a callback recycling another tracked handle',
      () {
    final bSpec =
        ViewModelSpec<_Node>(builder: () => _Node('b', events), key: 'b');
    late _Owner owner;
    owner = _Owner(ViewModelSpec(
        builder: () => _Node('a', events, unbound: (_, __) {
              instanceManager.recycle(_handle('b').instance);
            }),
        key: 'a'));
    addTearDown(owner.dispose);
    owner.vm;
    owner.read(bSpec);
    owner.dispose();
    expect(events.where((event) => event.startsWith('dispose:')), hasLength(2));
    expect(ViewModel.maybeReadCached<_Node>(key: 'a'), isNull);
    expect(ViewModel.maybeReadCached<_Node>(key: 'b'), isNull);
  });
}
