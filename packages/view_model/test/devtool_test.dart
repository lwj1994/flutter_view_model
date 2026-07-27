import 'package:flutter_test/flutter_test.dart';
import 'package:view_model/view_model.dart';
import 'package:view_model/src/devtool/service.dart';
import 'package:view_model/src/devtool/tracker.dart';
import 'package:view_model/src/get_instance/manager.dart';

class DevVM extends ViewModel {}

class OwnerDevVM extends ViewModel {}

class DevChildVM extends ViewModel {}

class DevParentVM extends ViewModel {
  DevParentVM(this.childSpec);

  final ViewModelFactory<DevChildVM> childSpec;

  DevChildVM get child => viewModelBinding.read(childSpec);
}

class FailingDevParentVM extends ViewModel {
  FailingDevParentVM(ViewModelFactory<DevChildVM> childSpec) {
    viewModelBinding.read(childSpec);
    throw StateError('parent construction failed');
  }
}

void main() {
  group('DevTools integration and tracker', () {
    /// Function-level comment: Verify service dispose when not initialized.
    test('service dispose does not throw when not initialized', () {
      DevToolsService.instance.dispose();
    });

    /// Function-level comment: Validate lifecycle tracking and relationships.
    test('tracker records lifecycle and relationships', () async {
      final tracker = DevToolTracker.instance;
      tracker.clear();

      // Create a VM with a binder
      final handle = instanceManager.getNotifier<DevVM>(
        factory: InstanceFactory<DevVM>(
          builder: () => DevVM(),
          arg: const InstanceArg(key: 'dev_key', bindingId: 'w1'),
        ),
      );

      // Add another watcher
      handle.bind('w2');

      final graph = tracker.dependencyGraph;
      expect(graph.viewModelInfos.isNotEmpty, isTrue);

      // getViewModelsForWatcher covers mapping lookup
      final vmsW1 = graph.getViewModelsForWatcher('w1');
      final vmsW2 = graph.getViewModelsForWatcher('w2');
      expect(vmsW1.isNotEmpty, isTrue);
      expect(vmsW2.isNotEmpty, isTrue);

      // Stats cover shared/orphaned/active counters
      final stats = tracker.getStats();
      expect(stats.activeInstances >= 1, isTrue);
      expect(stats.totalWatchers >= 1, isTrue);

      // Remove a viewModelBinding to trigger onUnbind path
      handle.unbind('w1');

      // Dispose VM to trigger onDispose path and cleanup
      handle.unbind('w2');
      await Future.delayed(Duration.zero);

      final statsAfter = tracker.getStats();
      expect(statsAfter.disposedInstances >= 1, isTrue);
    });

    /// Function-level comment: Ensure service initialize runs without errors.
    test('service initialize registers extensions once', () {
      final service = DevToolsService.instance;
      // Only call initialize once to avoid duplicate extension registration
      service.initialize();
    });

    /// Function-level comment: Listener error handling does not crash tracker.
    test('tracker listener error handling via clear()', () {
      final tracker = DevToolTracker.instance;
      tracker.clear();
      bool called = false;
      tracker.addListener(() {
        called = true;
        throw Exception('listener error');
      });
      // clear triggers _notifyListeners, error should be swallowed
      tracker.clear();
      expect(called, isTrue);
    });

    /// Function-level comment: getInstancesOfType returns instances correctly.
    test('dependencyGraph getInstancesOfType returns instances', () async {
      final tracker = DevToolTracker.instance;
      tracker.clear();

      final h1 = instanceManager.getNotifier<DevVM>(
        factory: InstanceFactory<DevVM>(
          builder: () => DevVM(),
          arg: const InstanceArg(key: 'k1', bindingId: 'wA'),
        ),
      );
      h1.bind('wB');

      final graph = tracker.dependencyGraph;
      final list = graph.getInstancesOfType('DevVM');
      expect(list.isNotEmpty, isTrue);
    });

    /// Function-level comment: Graph nodes/relations reflect active ownership.
    test('dependencyGraph nodes and relationships correctness', () async {
      final tracker = DevToolTracker.instance;
      tracker.clear();

      final h1 = instanceManager.getNotifier<DevVM>(
        factory: InstanceFactory<DevVM>(
          builder: () => DevVM(),
          arg: const InstanceArg(key: 'kX', bindingId: 'w3'),
        ),
      );
      h1.bind('w4');

      final graph = tracker.dependencyGraph;
      expect(graph.viewModelInfos.isNotEmpty, isTrue);
      // Each watcher should map to DevVM type
      expect(graph.watcherToViewModels['w3']?.contains('DevVM'), isTrue);
      expect(graph.watcherToViewModels['w4']?.contains('DevVM'), isTrue);
    });

    /// Function-level comment: InstanceId string contains key and tag info.
    test('instance id includes key and tag formatting', () async {
      final tracker = DevToolTracker.instance;
      tracker.clear();

      instanceManager.getNotifier<DevVM>(
        factory: InstanceFactory<DevVM>(
          builder: () => DevVM(),
          arg: const InstanceArg(key: 'kA', tag: 'tA', bindingId: 'wZ'),
        ),
      );

      final graph = tracker.dependencyGraph;
      final anyId = graph.viewModelInfos.keys.first;
      expect(anyId.contains('key: kA#'), isTrue);
      expect(anyId.contains('tag: tA#'), isTrue);
    });

    /// Function-level comment: service debug getters expose data structures.
    test('service debug getters expose data structures', () async {
      final tracker = DevToolTracker.instance;
      tracker.clear();

      final h = instanceManager.getNotifier<DevVM>(
        factory: InstanceFactory<DevVM>(
          builder: () => DevVM(),
          arg: const InstanceArg(key: 'kDBG', tag: 'tDBG', bindingId: 'wDBG'),
        ),
      );
      h.bind('wDBG2');

      final svc = DevToolsService.instance;
      svc.initialize();

      final vmData = svc.debugGetViewModelData();
      expect(vmData.containsKey('viewModels'), isTrue);
      expect(vmData.containsKey('stats'), isTrue);
      final vmJson =
          (vmData['viewModels'] as List<dynamic>).first as Map<String, dynamic>;
      expect(vmJson['owners'], isA<List<dynamic>>());
      expect(vmJson.containsKey('primaryOwner'), isTrue);
      expect(vmJson.containsKey('primaryOwnerHandoff'), isTrue);

      final graphData = svc.debugGetDependencyGraph();
      expect((graphData['viewModels'] as List).isNotEmpty, isTrue);
      expect((graphData['relationships'] as List).isNotEmpty, isTrue);
      expect(graphData.containsKey('nodes'), isFalse);
      expect(graphData.containsKey('edges'), isFalse);

      final stats = svc.debugGetStats();
      expect(stats['totalInstances']! >= 1, isTrue);
      expect(stats['totalWatchers']! >= 1, isTrue);
    });

    /// Function-level comment: tracker addListener returns remover.
    test('tracker addListener remover works', () {
      final tracker = DevToolTracker.instance;
      tracker.clear();
      int count = 0;
      final remove = tracker.addListener(() {
        count++;
      });
      tracker.clear();
      expect(count, 1);
      remove();
      tracker.clear();
      expect(count, 1);
    });

    test('tracker exposes owners and records primary owner handoff', () {
      final tracker = DevToolTracker.instance;
      tracker.resetForTesting();

      final ownerA = ViewModelBinding();
      final ownerB = ViewModelBinding();
      final spec = ViewModelSpec<OwnerDevVM>(
        key: 'owner-handoff',
        builder: OwnerDevVM.new,
      );

      final vm = ownerA.read<OwnerDevVM>(spec);
      expect(identical(ownerB.read<OwnerDevVM>(spec), vm), isTrue);

      var info = tracker.dependencyGraph.viewModelInfos.values.single;
      expect(info.owners, [ownerA.id, ownerB.id]);
      expect(info.primaryOwner, ownerA.id);
      expect(info.primaryOwnerHandoff, isNull);

      final initialGraph = DevToolsService.instance.debugGetDependencyGraph();
      final initialRelationships =
          (initialGraph['relationships'] as List<dynamic>)
              .cast<Map<String, dynamic>>();
      expect(initialRelationships, hasLength(2));
      expect(
        initialRelationships.singleWhere(
          (relationship) => relationship['source'] == ownerA.id,
        )['isPrimaryOwner'],
        isTrue,
      );
      expect(
        initialRelationships.singleWhere(
          (relationship) => relationship['source'] == ownerB.id,
        )['isPrimaryOwner'],
        isFalse,
      );

      ownerA.dispose();

      info = tracker.dependencyGraph.viewModelInfos.values.single;
      expect(info.owners, [ownerB.id]);
      expect(info.primaryOwner, ownerB.id);
      expect(info.primaryOwnerHandoff?.from, ownerA.id);
      expect(info.primaryOwnerHandoff?.to, ownerB.id);

      final serviceData = DevToolsService.instance.debugGetViewModelData();
      final viewModelJson = (serviceData['viewModels'] as List<dynamic>).single
          as Map<String, dynamic>;
      expect(viewModelJson['owners'], [ownerB.id]);
      expect(viewModelJson['primaryOwner'], ownerB.id);
      expect(
        viewModelJson['primaryOwnerHandoff'],
        containsPair('from', ownerA.id),
      );
      expect(
        viewModelJson['primaryOwnerHandoff'],
        containsPair('to', ownerB.id),
      );

      final graphData = DevToolsService.instance.debugGetDependencyGraph();
      final node = (graphData['viewModels'] as List<dynamic>).single
          as Map<String, dynamic>;
      expect(node['owners'], [ownerB.id]);
      expect(node['primaryOwner'], ownerB.id);
      final relationship = (graphData['relationships'] as List<dynamic>).single
          as Map<String, dynamic>;
      expect(relationship['isPrimaryOwner'], isTrue);

      ownerB.dispose();

      info = tracker.dependencyGraph.viewModelInfos.values.single;
      expect(info.owners, isEmpty);
      expect(info.primaryOwner, isNull);
      expect(info.primaryOwnerHandoff?.from, ownerA.id);
      expect(info.primaryOwnerHandoff?.to, ownerB.id);
    });

    test('lists empty bindings and virtual parent-child relationships', () {
      ViewModel.reset();

      final emptyBinding = ViewModelBinding()..init();
      final rootBinding = ViewModelBinding()..init();
      addTearDown(() {
        emptyBinding.dispose();
        rootBinding.dispose();
        ViewModel.reset();
      });

      final childSpec = ViewModelSpec<DevChildVM>(
        key: 'devtool-child',
        builder: DevChildVM.new,
      );
      final parentSpec = ViewModelSpec<DevParentVM>(
        key: 'devtool-parent',
        builder: () => DevParentVM(childSpec),
      );

      final parent = rootBinding.read(parentSpec);
      final child = parent.child;
      final graph = DevToolTracker.instance.dependencyGraph;
      final parentInfo = graph.viewModelInfos.values.singleWhere(
        (info) => info.typeName == 'DevParentVM',
      );
      final childInfo = graph.viewModelInfos.values.singleWhere(
        (info) => info.typeName == 'DevChildVM',
      );
      final dependencyBinding = graph.bindingInfos.values.singleWhere(
        (info) => info.kind == 'dependency',
      );

      expect(graph.bindingInfos[emptyBinding.id]?.kind, 'root');
      expect(graph.bindingInfos[rootBinding.id]?.kind, 'root');
      expect(dependencyBinding.parentViewModelId, parentInfo.instanceId);
      expect(dependencyBinding.parentViewModelType, 'DevParentVM');
      expect(childInfo.watchers, contains(dependencyBinding.bindingId));
      expect(childInfo.watchers, contains(rootBinding.id));
      expect(identical(child, parent.child), isTrue);

      final service = DevToolsService.instance;
      final data = service.debugGetViewModelData();
      expect((data['bindings'] as List<dynamic>), hasLength(3));

      final graphData = service.debugGetDependencyGraph();
      final bindings =
          (graphData['bindings'] as List<dynamic>).cast<Map<String, dynamic>>();
      final relationships = (graphData['relationships'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      expect(
        bindings.singleWhere((item) => item['id'] == emptyBinding.id),
        containsPair('isActive', true),
      );
      expect(
        relationships,
        contains(
          allOf(
            containsPair('source', parentInfo.instanceId),
            containsPair('target', dependencyBinding.bindingId),
            containsPair('kind', 'viewModelOwnsDependencyBinding'),
          ),
        ),
      );
      expect(
        relationships,
        contains(
          allOf(
            containsPair('source', dependencyBinding.bindingId),
            containsPair('target', childInfo.instanceId),
            containsPair('kind', 'bindingOwnsViewModel'),
          ),
        ),
      );

      emptyBinding.dispose();
      expect(
        DevToolTracker
            .instance.dependencyGraph.bindingInfos[emptyBinding.id]?.isDisposed,
        isTrue,
      );
    });

    test('failed parent construction removes its pending virtual binding', () {
      ViewModel.reset();

      final rootBinding = ViewModelBinding()..init();
      addTearDown(() {
        rootBinding.dispose();
        ViewModel.reset();
      });
      final childSpec = ViewModelSpec<DevChildVM>(
        key: 'failed-devtool-child',
        builder: DevChildVM.new,
      );
      final parentSpec = ViewModelSpec<FailingDevParentVM>(
        key: 'failed-devtool-parent',
        builder: () => FailingDevParentVM(childSpec),
      );

      expect(() => rootBinding.read(parentSpec), throwsStateError);

      final graph = DevToolTracker.instance.dependencyGraph;
      expect(
        graph.bindingInfos.values.where(
          (info) => info.kind == 'dependency',
        ),
        isEmpty,
      );
      expect(graph.bindingInfos.keys, [rootBinding.id]);
    });

    test('resetForTesting clears graph and tracker listeners silently', () {
      final tracker = DevToolTracker.instance;
      var notifications = 0;
      tracker.addListener(() => notifications++);

      tracker.resetForTesting();

      expect(tracker.dependencyGraph.viewModelInfos, isEmpty);
      expect(tracker.dependencyGraph.watcherToViewModels, isEmpty);
      expect(tracker.dependencyGraph.bindingInfos, isEmpty);
      expect(tracker.dependencyGraph.typeToInstances, isEmpty);
      expect(notifications, 0);

      tracker.clear();
      expect(notifications, 0);
    });

    /// Function-level comment: toString coverage for info and stats.
    test('toString for ViewModelInfo and DependencyStats', () async {
      final tracker = DevToolTracker.instance;
      tracker.clear();

      instanceManager.getNotifier<DevVM>(
        factory: InstanceFactory<DevVM>(
          builder: () => DevVM(),
          arg: const InstanceArg(key: 'kTS', bindingId: 'wTS'),
        ),
      );

      final graph = tracker.dependencyGraph;
      final anyInfo = graph.viewModelInfos.values.first;
      final infoStr = anyInfo.toString();
      expect(infoStr.contains('ViewModelInfo'), isTrue);

      final stats = tracker.getStats();
      final statsStr = stats.toString();
      expect(statsStr.contains('DependencyStats'), isTrue);
    });
  });
}
