/// Dependency tracking system for ViewModels.
///
/// This file provides comprehensive dependency tracking capabilities for the
/// ViewModel system, including relationship management, lifecycle monitoring,
/// and statistics collection. It helps developers understand and debug
/// ViewModel usage patterns and dependencies.
///
/// @author luwenjie on 2025/3/25 17:00:38
library;

import 'package:flutter/foundation.dart';
import 'package:view_model/src/get_instance/store.dart';
import 'package:view_model/src/log.dart';

import '../view_model/view_model.dart';

/// Singleton dependency tracker for ViewModels.
///
/// This class monitors and manages dependency relationships between ViewModels
/// and their watchers (typically widgets). It provides comprehensive tracking
/// of ViewModel lifecycle events, watcher relationships, and usage statistics.
///
/// Key features:
/// - Tracks ViewModel creation, disposal, and watcher relationships
/// - Provides real-time dependency graph data
/// - Offers statistics for debugging and optimization
/// - Supports listeners for dependency change notifications
///
/// Example:
/// ```dart
/// // Get dependency statistics
/// final stats = DependencyTracker.instance.getStats();
/// print('Active ViewModels: ${stats.activeInstances}');
///
/// // Listen to dependency changes
/// final removeListener = DependencyTracker.instance.addListener(() {
///   print('Dependencies changed!');
/// });
///
/// // Clean up
/// removeListener();
/// ```
class DevToolTracker extends ViewModelLifecycle {
  static final DevToolTracker _instance = DevToolTracker._();

  /// Gets the singleton instance of the dependency tracker.
  static DevToolTracker get instance => _instance;

  DevToolTracker._();

  /// Maps watcher IDs to the set of ViewModel type names they watch.
  ///
  /// This allows quick lookup of which ViewModel types are being watched
  /// by a specific widget or watcher.
  final Map<String, Set<String>> _watcherToViewModels = {};

  /// Maps ViewModel instance IDs to their detailed information.
  ///
  /// Contains comprehensive information about each ViewModel instance
  /// including lifecycle state, watchers, and metadata.
  final Map<String, ViewModelInfo> _viewModelInfos = {};

  /// Maps ViewModel type names to sets of their instance IDs.
  ///
  /// Enables efficient lookup of all instances of a particular ViewModel type.
  final Map<String, Set<String>> _typeToInstances = {};

  /// List of callbacks to notify when dependency relationships change.
  ///
  /// These listeners are called whenever ViewModels are created, disposed,
  /// or when watcher relationships are modified.
  final List<VoidCallback> _listeners = [];

  /// Gets a snapshot of all current dependency relationship data.
  ///
  /// Returns an immutable [DependencyGraph] containing all current
  /// dependency relationships, ViewModel information, and type mappings.
  /// This is useful for debugging, visualization, or analysis tools.
  ///
  /// The returned data is a snapshot and won't reflect future changes.
  DependencyGraph get dependencyGraph {
    return DependencyGraph(
      watcherToViewModels: Map.unmodifiable(_watcherToViewModels),
      viewModelInfos: Map.unmodifiable(_viewModelInfos),
      typeToInstances: Map.unmodifiable(_typeToInstances),
    );
  }

  /// Adds a listener for dependency relationship changes.
  ///
  /// The [listener] callback will be called whenever:
  /// - A ViewModel is created or disposed
  /// - A watcher is added or removed from a ViewModel
  /// - The dependency graph structure changes
  ///
  /// Returns a function that can be called to remove the listener.
  ///
  /// Example:
  /// ```dart
  /// final removeListener = DependencyTracker.instance.addListener(() {
  ///   print('Dependencies changed!');
  /// });
  ///
  /// // Later, remove the listener
  /// removeListener();
  /// ```
  VoidCallback addListener(VoidCallback listener) {
    _listeners.add(listener);
    return () => _listeners.remove(listener);
  }

  /// Notifies all registered listeners that dependency relationships have changed.
  ///
  /// This method is called internally whenever the dependency graph is modified.
  /// Listeners are called safely with error handling to prevent one failing
  /// listener from affecting others.
  void _notifyListeners() {
    for (final listener in _listeners) {
      try {
        listener();
      } catch (e) {
        viewModelLog('DependencyTracker listener error: $e');
      }
    }
  }

  /// Called when a ViewModel is created.
  ///
  /// This lifecycle method tracks the creation of new ViewModel instances,
  /// recording their metadata and updating internal mappings.
  ///
  /// Parameters:
  /// - [viewModel]: The newly created ViewModel instance
  /// - [arg]: The instance arguments used for creation (key, tag, etc.)
  @override
  void onCreate(ViewModel viewModel, InstanceArg arg) {
    final instanceId = _getInstanceId(viewModel, arg);
    final typeName = viewModel.runtimeType.toString();

    _viewModelInfos[instanceId] = ViewModelInfo(
      instanceId: instanceId,
      typeName: typeName,
      key: arg.key,
      tag: arg.tag?.toString(),
      createTime: DateTime.now(),
      watchers: {},
    );

    _typeToInstances.putIfAbsent(typeName, () => {}).add(instanceId);

    viewModelLog('📱 ViewModel Created: $typeName (id: $instanceId)');

    _notifyListeners();
  }

  /// Called when a watcher is added to a ViewModel.
  ///
  /// This method tracks when widgets or other components start watching
  /// a ViewModel, establishing the dependency relationship.
  ///
  /// Parameters:
  /// - [viewModel]: The ViewModel being watched
  /// - [arg]: The instance arguments for the ViewModel
  /// - [newWatchId]: Unique identifier for the new watcher
  @override
  void onAddWatcher(ViewModel viewModel, InstanceArg arg, String newWatchId) {
    final instanceId = _getInstanceId(viewModel, arg);
    final typeName = viewModel.runtimeType.toString();

    // Update watcher -> viewModels mapping
    _watcherToViewModels.putIfAbsent(newWatchId, () => {}).add(typeName);

    // Update watchers in viewModel information
    final info = _viewModelInfos[instanceId];
    if (info != null) {
      _viewModelInfos[instanceId] = info.copyWith(
        watchers: {...info.watchers, newWatchId},
      );
    }

    viewModelLog('🔗 Watcher Added: $newWatchId -> $typeName');

    _notifyListeners();
  }

  /// Called when a watcher is removed from a ViewModel.
  ///
  /// This method tracks when widgets or other components stop watching
  /// a ViewModel, breaking the dependency relationship.
  ///
  /// Parameters:
  /// - [viewModel]: The ViewModel no longer being watched
  /// - [arg]: The instance arguments for the ViewModel
  /// - [removedWatchId]: Unique identifier for the removed watcher
  @override
  void onRemoveWatcher(
      ViewModel viewModel, InstanceArg arg, String removedWatchId) {
    final instanceId = _getInstanceId(viewModel, arg);
    final typeName = viewModel.runtimeType.toString();

    // Remove from watcher -> viewModels mapping
    final viewModels = _watcherToViewModels[removedWatchId];
    if (viewModels != null) {
      viewModels.remove(typeName);
      if (viewModels.isEmpty) {
        _watcherToViewModels.remove(removedWatchId);
      }
    }

    // Remove watcher from viewModel information
    final info = _viewModelInfos[instanceId];
    if (info != null) {
      final newWatchers = Set<String>.from(info.watchers);
      newWatchers.remove(removedWatchId);
      _viewModelInfos[instanceId] = info.copyWith(watchers: newWatchers);
    }

    viewModelLog('🔌 Watcher Removed: $removedWatchId -> $typeName');
    _notifyListeners();
  }

  /// Called when a ViewModel is disposed.
  ///
  /// This method tracks ViewModel disposal, marking instances as disposed
  /// rather than removing them entirely to maintain historical data.
  /// It also cleans up all associated watcher relationships.
  ///
  /// Parameters:
  /// - [viewModel]: The ViewModel being disposed
  /// - [arg]: The instance arguments for the ViewModel
  @override
  void onDispose(ViewModel viewModel, InstanceArg arg) {
    final instanceId = _getInstanceId(viewModel, arg);
    final typeName = viewModel.runtimeType.toString();

    // Mark instance as disposed instead of removing it
    final info = _viewModelInfos[instanceId];
    if (info != null) {
      _viewModelInfos[instanceId] = info.copyWith(
        isDisposed: true,
        disposeTime: DateTime.now(),
        watchers: <String>{}, // Clear watchers as they are no longer valid
      );
    }

    // Clean up related watcher mappings
    if (info != null) {
      for (final watcherId in info.watchers) {
        final viewModels = _watcherToViewModels[watcherId];
        if (viewModels != null) {
          viewModels.remove(typeName);
          if (viewModels.isEmpty) {
            _watcherToViewModels.remove(watcherId);
          }
        }
      }
    }

    viewModelLog('🗑️ ViewModel Disposed: $typeName (id: $instanceId)');
    _notifyListeners();
  }

  /// Generates a unique identifier for a ViewModel instance.
  ///
  /// The identifier combines the ViewModel's runtime type, key, and hash code
  /// to create a unique string that can be used to track the instance.
  ///
  /// Parameters:
  /// - [viewModel]: The ViewModel instance
  /// - [arg]: The instance arguments containing key and other metadata
  ///
  /// Returns a unique string identifier for the instance.
  String _getInstanceId(ViewModel viewModel, InstanceArg arg) {
    return '${viewModel.runtimeType}_${arg.key}_${viewModel.hashCode}';
  }

  /// Clears all tracking data.
  ///
  /// This method removes all stored dependency information, including
  /// watcher relationships, ViewModel information, and type mappings.
  /// Useful for testing or when a complete reset is needed.
  ///
  /// Note: This will trigger listener notifications.
  void clear() {
    _watcherToViewModels.clear();
    _viewModelInfos.clear();
    _typeToInstances.clear();
    _notifyListeners();
  }

  /// Gets comprehensive statistics about the current dependency state.
  ///
  /// This method analyzes all tracked ViewModels and their relationships
  /// to provide useful metrics for debugging and optimization.
  ///
  /// Returns a [DependencyStats] object containing:
  /// - Active and disposed instance counts
  /// - Shared instances (watched by multiple watchers)
  /// - Orphaned instances (no current watchers)
  /// - Total watcher and type counts
  ///
  /// Example:
  /// ```dart
  /// final stats = DependencyTracker.instance.getStats();
  /// print('Active ViewModels: ${stats.activeInstances}');
  /// print('Memory leaks (orphaned): ${stats.orphanedInstances}');
  /// ```
  DependencyStats getStats() {
    final allInstances = _viewModelInfos.values;
    final activeInstances =
        allInstances.where((info) => !info.isDisposed).length;
    final disposedInstances =
        allInstances.where((info) => info.isDisposed).length;
    final sharedInstances = allInstances
        .where((info) => !info.isDisposed && info.watchers.length > 1)
        .length;
    final orphanedInstances = allInstances
        .where((info) => !info.isDisposed && info.watchers.isEmpty)
        .length;
    final totalWatchers = _watcherToViewModels.length;

    return DependencyStats(
      activeInstances: activeInstances,
      sharedInstances: sharedInstances,
      orphanedInstances: orphanedInstances,
      totalWatchers: totalWatchers,
      viewModelTypes: _typeToInstances.length,
      disposedInstances: disposedInstances,
    );
  }
}

/// Detailed information about a ViewModel instance.
///
/// This class contains comprehensive metadata about a ViewModel instance
/// including its lifecycle state, relationships, and timing information.
///
/// Used by the dependency tracker to maintain detailed records of all
/// ViewModel instances for debugging and analysis purposes.
class ViewModelInfo {
  /// Unique identifier for this ViewModel instance.
  final String instanceId;

  /// The runtime type name of the ViewModel.
  final String typeName;

  /// Optional key used when creating this ViewModel instance.
  final String? key;

  /// Optional tag used when creating this ViewModel instance.
  final String? tag;

  /// Timestamp when this ViewModel was created.
  final DateTime createTime;

  /// Set of watcher IDs currently watching this ViewModel.
  final Set<String> watchers;

  /// Whether this ViewModel instance has been disposed.
  final bool isDisposed;

  /// Timestamp when this ViewModel was disposed, if applicable.
  final DateTime? disposeTime;

  /// Creates a new ViewModel information record.
  ///
  /// Parameters:
  /// - [instanceId]: Unique identifier for the instance
  /// - [typeName]: Runtime type name of the ViewModel
  /// - [key]: Optional key used for creation
  /// - [tag]: Optional tag used for creation
  /// - [createTime]: When the ViewModel was created
  /// - [watchers]: Set of current watcher IDs
  /// - [isDisposed]: Whether the instance is disposed (defaults to false)
  /// - [disposeTime]: When the instance was disposed (optional)
  const ViewModelInfo({
    required this.instanceId,
    required this.typeName,
    this.key,
    this.tag,
    required this.createTime,
    required this.watchers,
    this.isDisposed = false,
    this.disposeTime,
  });

  /// Creates a copy of this ViewModelInfo with optionally updated fields.
  ///
  /// This method allows updating specific fields while keeping others unchanged.
  /// Commonly used when updating the watcher list or disposal status.
  ///
  /// Parameters:
  /// - [instanceId]: New instance ID (optional)
  /// - [typeName]: New type name (optional)
  /// - [key]: New key (optional)
  /// - [tag]: New tag (optional)
  /// - [createTime]: New creation time (optional)
  /// - [watchers]: New watcher set (optional)
  /// - [isDisposed]: New disposal status (optional)
  /// - [disposeTime]: New disposal time (optional)
  ///
  /// Returns a new ViewModelInfo instance with updated fields.
  ViewModelInfo copyWith({
    String? instanceId,
    String? typeName,
    String? key,
    String? tag,
    DateTime? createTime,
    Set<String>? watchers,
    bool? isDisposed,
    DateTime? disposeTime,
  }) {
    return ViewModelInfo(
      instanceId: instanceId ?? this.instanceId,
      typeName: typeName ?? this.typeName,
      key: key ?? this.key,
      tag: tag ?? this.tag,
      createTime: createTime ?? this.createTime,
      watchers: watchers ?? this.watchers,
      isDisposed: isDisposed ?? this.isDisposed,
      disposeTime: disposeTime ?? this.disposeTime,
    );
  }

  @override
  String toString() {
    return 'ViewModelInfo(id: $instanceId, type: $typeName, key: $key, tag: $tag, watchers: ${watchers.length}, isDisposed: $isDisposed)';
  }
}

/// Immutable snapshot of dependency relationship data.
///
/// This class provides a read-only view of all dependency relationships
/// at a specific point in time. It contains mappings between watchers,
/// ViewModels, and types, along with detailed instance information.
///
/// Used for debugging, visualization, and analysis of ViewModel usage patterns.
class DependencyGraph {
  /// Maps watcher IDs to sets of ViewModel type names they watch.
  final Map<String, Set<String>> watcherToViewModels;

  /// Maps ViewModel instance IDs to their detailed information.
  final Map<String, ViewModelInfo> viewModelInfos;

  /// Maps ViewModel type names to sets of their instance IDs.
  final Map<String, Set<String>> typeToInstances;

  /// Creates a new dependency graph snapshot.
  ///
  /// Parameters:
  /// - [watcherToViewModels]: Watcher to ViewModel type mappings
  /// - [viewModelInfos]: Instance ID to ViewModel info mappings
  /// - [typeToInstances]: Type name to instance ID mappings
  const DependencyGraph({
    required this.watcherToViewModels,
    required this.viewModelInfos,
    required this.typeToInstances,
  });

  /// Gets all ViewModel instances watched by a specific watcher.
  ///
  /// This method finds all ViewModel instances that are currently being
  /// watched by the specified watcher ID.
  ///
  /// Parameters:
  /// - [watcherId]: The unique identifier of the watcher
  ///
  /// Returns a list of [ViewModelInfo] objects for ViewModels watched
  /// by the specified watcher.
  List<ViewModelInfo> getViewModelsForWatcher(String watcherId) {
    final typeNames = watcherToViewModels[watcherId] ?? {};
    final result = <ViewModelInfo>[];

    for (final typeName in typeNames) {
      final instanceIds = typeToInstances[typeName] ?? {};
      for (final instanceId in instanceIds) {
        final info = viewModelInfos[instanceId];
        if (info != null && info.watchers.contains(watcherId)) {
          result.add(info);
        }
      }
    }

    return result;
  }

  /// Gets all instances of a specific ViewModel type.
  ///
  /// This method retrieves all instances (both active and disposed)
  /// of the specified ViewModel type.
  ///
  /// Parameters:
  /// - [typeName]: The runtime type name of the ViewModel
  ///
  /// Returns a list of [ViewModelInfo] objects for all instances
  /// of the specified type.
  List<ViewModelInfo> getInstancesOfType(String typeName) {
    final instanceIds = typeToInstances[typeName] ?? {};
    return instanceIds
        .map((id) => viewModelInfos[id])
        .where((info) => info != null)
        .cast<ViewModelInfo>()
        .toList();
  }
}

/// Statistical information about ViewModel dependencies.
///
/// This class provides comprehensive metrics about the current state
/// of ViewModel instances and their relationships. Useful for debugging,
/// performance monitoring, and identifying potential memory leaks.
///
/// Key metrics:
/// - **Active Instances**: ViewModels currently in use
/// - **Disposed Instances**: ViewModels that have been disposed
/// - **Shared Instances**: ViewModels watched by multiple watchers
/// - **Orphaned Instances**: Active ViewModels with no watchers (potential leaks)
/// - **Total Watchers**: Number of active watcher relationships
/// - **ViewModel Types**: Number of different ViewModel types in use
class DependencyStats {
  /// Number of ViewModel instances that are currently active (not disposed).
  final int activeInstances;

  /// Number of ViewModel instances that are watched by multiple watchers.
  ///
  /// High numbers may indicate efficient resource sharing, while very high
  /// numbers might suggest overly complex dependency relationships.
  final int sharedInstances;

  /// Number of active ViewModel instances that have no current watchers.
  ///
  /// This often indicates potential memory leaks where ViewModels are
  /// created but not properly disposed when no longer needed.
  final int orphanedInstances;

  /// Total number of active watcher relationships.
  final int totalWatchers;

  /// Number of different ViewModel types currently tracked.
  final int viewModelTypes;

  /// Number of ViewModel instances that have been disposed.
  ///
  /// This count is maintained for historical analysis and debugging.
  final int disposedInstances;

  /// Creates a new dependency statistics snapshot.
  ///
  /// Parameters:
  /// - [activeInstances]: Count of active ViewModel instances
  /// - [sharedInstances]: Count of ViewModels with multiple watchers
  /// - [orphanedInstances]: Count of ViewModels with no watchers
  /// - [totalWatchers]: Total number of watcher relationships
  /// - [viewModelTypes]: Number of different ViewModel types
  /// - [disposedInstances]: Count of disposed ViewModel instances
  const DependencyStats({
    required this.activeInstances,
    required this.sharedInstances,
    required this.orphanedInstances,
    required this.totalWatchers,
    required this.viewModelTypes,
    required this.disposedInstances,
  });

  @override
  String toString() {
    return '''
DependencyStats:
  Active Instances: $activeInstances
  Disposed Instances: $disposedInstances
  Shared Instances: $sharedInstances
  Orphaned Instances: $orphanedInstances
  Total Watchers: $totalWatchers
  ViewModel Types: $viewModelTypes''';
  }
}
