import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import '../dependency/dependency_tracker.dart';

/// DevTools service for communicating with the DevTools extension
class DevToolsService {
  static DevToolsService? _instance;
  static DevToolsService get instance => _instance ??= DevToolsService._();

  DevToolsService._();

  StreamSubscription? _messageSubscription;
  bool _isInitialized = false;

  /// Initialize the DevTools service
  void initialize() {
    if (_isInitialized) return;
    _registerServiceExtensions();
    _isInitialized = true;
  }

  /// Dispose the DevTools service
  void dispose() {
    _messageSubscription?.cancel();
    _messageSubscription = null;
    _isInitialized = false;
  }

  void _registerServiceExtensions() {
    developer.registerExtension('ext.view_model.getViewModelData',
        (method, parameters) async {
      try {
        final data = _getViewModelData();
        return developer.ServiceExtensionResponse.result(jsonEncode(data));
      } catch (e) {
        return developer.ServiceExtensionResponse.error(
          developer.ServiceExtensionResponse.extensionError,
          'DevTools extension error: Unable to retrieve ViewModel data. Please ensure ViewModels are properly configured.',
        );
      }
    });

    developer.registerExtension('ext.view_model.getDependencyGraph',
        (method, parameters) async {
      try {
        final data = _getDependencyGraph();
        return developer.ServiceExtensionResponse.result(jsonEncode(data));
      } catch (e) {
        return developer.ServiceExtensionResponse.error(
          developer.ServiceExtensionResponse.extensionError,
          'DevTools extension error: Unable to retrieve dependency graph. Please check ViewModel dependency tracking configuration.',
        );
      }
    });
  }

  Map<String, dynamic> _getViewModelData() {
    final tracker = DependencyTracker.instance;
    final graph = tracker.dependencyGraph;

    final viewModels = graph.viewModelInfos.values
        .map((vm) => {
              'id': vm.instanceId,
              'type': vm.typeName,
              'key': vm.key,
              'tag': vm.tag,
              'isActive': !vm.isDisposed,
              'isDisposed': vm.isDisposed,
              'createdAt': vm.createTime.toIso8601String(),
              'disposeTime': vm.disposeTime?.toIso8601String(),
              'watchers': vm.watchers.toList(),
            })
        .toList();

    final stats = _getStatsFromTracker();

    return {
      'viewModels': viewModels,
      'stats': stats,
    };
  }

  Map<String, dynamic> _getDependencyGraph() {
    final tracker = DependencyTracker.instance;
    final graph = tracker.dependencyGraph;

    final dependencies = <Map<String, dynamic>>[];

    for (final vm in graph.viewModelInfos.values) {
      for (final watcher in vm.watchers) {
        dependencies.add({
          'from': watcher,
          'to': vm.instanceId,
          'type': 'watches',
        });
      }
    }

    return {
      'nodes': graph.viewModelInfos.values
          .map((vm) => {
                'id': vm.instanceId,
                'type': vm.typeName,
                'label': '${vm.typeName}\n${vm.key ?? vm.instanceId}',
                'isActive': true,
              })
          .toList(),
      'edges': dependencies,
    };
  }

  Map<String, int> _getStatsFromTracker() {
    final stats = DependencyTracker.instance.getStats();

    return {
      'totalInstances': stats.activeInstances + stats.disposedInstances,
      'activeInstances': stats.activeInstances,
      'disposedInstances': stats.disposedInstances,
      'sharedInstances': stats.sharedInstances,
      'orphanedInstances': stats.orphanedInstances,
      'totalWatchers': stats.totalWatchers,
      'viewModelTypes': stats.viewModelTypes,
    };
  }
}
