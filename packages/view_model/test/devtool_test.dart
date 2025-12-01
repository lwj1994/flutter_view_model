import 'package:flutter_test/flutter_test.dart';
import 'package:view_model/view_model.dart';
import 'package:view_model/src/devtool/service.dart';
import 'package:view_model/src/devtool/tracker.dart';
import 'package:view_model/src/get_instance/manager.dart';

class DevVM extends ViewModel {}

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
          arg: const InstanceArg(key: 'dev_key', vefId: 'w1'),
        ),
      );

      // Add another watcher
      handle.bindVef('w2');

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

      // Remove a vef to trigger onUnbind path
      handle.unbindVef('w1');

      // Dispose VM to trigger onDispose path and cleanup
      handle.unbindVef('w2');
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
          arg: const InstanceArg(key: 'k1', vefId: 'wA'),
        ),
      );
      h1.bindVef('wB');

      final graph = tracker.dependencyGraph;
      final list = graph.getInstancesOfType('DevVM');
      expect(list.isNotEmpty, isTrue);
    });

    /// Function-level comment: Graph nodes/edges reflect watcher relations.
    test('dependencyGraph nodes and edges correctness', () async {
      final tracker = DevToolTracker.instance;
      tracker.clear();

      final h1 = instanceManager.getNotifier<DevVM>(
        factory: InstanceFactory<DevVM>(
          builder: () => DevVM(),
          arg: const InstanceArg(key: 'kX', vefId: 'w3'),
        ),
      );
      h1.bindVef('w4');

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

      final handle = instanceManager.getNotifier<DevVM>(
        factory: InstanceFactory<DevVM>(
          builder: () => DevVM(),
          arg: const InstanceArg(key: 'kA', tag: 'tA', vefId: 'wZ'),
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
          arg: const InstanceArg(key: 'kDBG', tag: 'tDBG', vefId: 'wDBG'),
        ),
      );
      h.bindVef('wDBG2');

      final svc = DevToolsService.instance;
      svc.initialize();

      final vmData = svc.debugGetViewModelData();
      expect(vmData.containsKey('viewModels'), isTrue);
      expect(vmData.containsKey('stats'), isTrue);

      final graphData = svc.debugGetDependencyGraph();
      expect((graphData['nodes'] as List).isNotEmpty, isTrue);
      expect((graphData['edges'] as List).isNotEmpty, isTrue);

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

    /// Function-level comment: toString coverage for info and stats.
    test('toString for ViewModelInfo and DependencyStats', () async {
      final tracker = DevToolTracker.instance;
      tracker.clear();

      instanceManager.getNotifier<DevVM>(
        factory: InstanceFactory<DevVM>(
          builder: () => DevVM(),
          arg: const InstanceArg(key: 'kTS', vefId: 'wTS'),
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
