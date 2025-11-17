/// DevTools integration service for ViewModel debugging.
///
/// This file provides integration with Flutter DevTools, enabling developers
/// to inspect ViewModel instances, dependency relationships, and usage
/// statistics through the DevTools extension interface.
///
/// The service exposes ViewModel data through service extensions that can be
/// consumed by DevTools panels for visualization and debugging.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:view_model/src/log.dart';

import 'tracker.dart';

/// Service for integrating ViewModel debugging with Flutter DevTools.
///
/// This singleton service provides communication between the ViewModel system
/// and Flutter DevTools extension. It exposes ViewModel data, dependency
/// graphs, and statistics through service extensions that can be consumed by
/// DevTools.
///
/// Key features:
/// - Real-time ViewModel instance monitoring
/// - Dependency relationship visualization
/// - Performance and usage statistics
/// - Integration with Flutter DevTools panels
///
/// Example usage:
/// ```dart
/// // Initialize the service (typically done automatically)
/// DevToolsService.instance.initialize();
///
/// // The service will automatically expose data to DevTools
/// // No manual intervention required for basic functionality
/// ```
class DevToolsService {
  static DevToolsService? _instance;

  /// Gets the singleton instance of the DevTools service.
  static DevToolsService get instance => _instance ??= DevToolsService._();

  DevToolsService._();

  /// Subscription for handling DevTools messages (reserved for future use).
  StreamSubscription? _messageSubscription;

  /// Whether the service has been initialized.
  bool _isInitialized = false;

  /// Initializes the DevTools service and registers service extensions.
  ///
  /// This method sets up the communication bridge between the ViewModel system
  /// and Flutter DevTools. It registers service extensions that DevTools can
  /// call to retrieve ViewModel data and dependency information.
  ///
  /// The method is idempotent - calling it multiple times has no additional effect.
  ///
  /// Service extensions registered:
  /// - `ext.view_model.getViewModelData`: Returns ViewModel instances and statistics
  /// - `ext.view_model.getDependencyGraph`: Returns dependency relationship data
  void initialize() {
    if (_isInitialized) return;
    _registerServiceExtensions();
    _isInitialized = true;
  }

  /// Disposes the DevTools service and cleans up resources.
  ///
  /// This method cancels any active subscriptions and resets the initialization
  /// state. After calling this method, the service can be re-initialized if needed.
  void dispose() {
    _messageSubscription?.cancel();
    _messageSubscription = null;
    _isInitialized = false;
  }

  /// Registers service extensions for DevTools communication.
  ///
  /// This method sets up the service extensions that DevTools can call to
  /// retrieve ViewModel data. Each extension is registered with error handling
  /// to provide meaningful error messages if data retrieval fails.
  ///
  /// Extensions registered:
  /// - `ext.view_model.getViewModelData`: Returns ViewModel instances and stats
  /// - `ext.view_model.getDependencyGraph`: Returns dependency graph data
  void _registerServiceExtensions() {
    viewModelLog("DevTool registerExtension: ext.view_model.getViewModelData");
    developer.registerExtension('ext.view_model.getViewModelData',
        (method, parameters) async {
      try {
        final data = _getViewModelData();
        final res = jsonEncode(data);
        viewModelLog("DevTool _getViewModelData suucess: $res");
        return developer.ServiceExtensionResponse.result(res);
      } catch (e) {
        viewModelLog("DevTool _getViewModelData error: $e");
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

  /// Retrieves comprehensive ViewModel data for DevTools display.
  ///
  /// This method collects all ViewModel instances from the dependency tracker
  /// and formats them for consumption by DevTools. The data includes instance
  /// metadata, lifecycle information, and current watcher relationships.
  ///
  /// Returns a map containing:
  /// - `viewModels`: List of ViewModel instance data
  /// - `stats`: Statistical summary of ViewModel usage
  ///
  /// Each ViewModel entry includes:
  /// - Instance ID, type name, key, and tag
  /// - Lifecycle state (active/disposed)
  /// - Creation and disposal timestamps
  /// - List of current watchers
  Map<String, dynamic> _getViewModelData() {
    final tracker = DevToolTracker.instance;
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

  /// Retrieves dependency graph data for DevTools visualization.
  ///
  /// This method constructs a graph representation of ViewModel dependencies
  /// suitable for visualization in DevTools. The graph shows relationships
  /// between watchers and ViewModel instances.
  ///
  /// Returns a map containing:
  /// - `nodes`: List of ViewModel instances as graph nodes
  /// - `edges`: List of dependency relationships as graph edges
  ///
  /// Each node represents a ViewModel instance with:
  /// - Unique ID, type name, and display label
  /// - Activity status for visual styling
  ///
  /// Each edge represents a "watches" relationship from a watcher to a ViewModel.
  Map<String, dynamic> _getDependencyGraph() {
    final tracker = DevToolTracker.instance;
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

  /// Extracts statistical data from the dependency tracker.
  ///
  /// This method converts the [DependencyStats] object from the tracker
  /// into a format suitable for DevTools consumption. It includes all
  /// key metrics about ViewModel usage and relationships.
  ///
  /// Returns a map with statistical counters:
  /// - Total, active, and disposed instance counts
  /// - Shared and orphaned instance counts
  /// - Total watcher and type counts
  Map<String, int> _getStatsFromTracker() {
    final stats = DevToolTracker.instance.getStats();

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
