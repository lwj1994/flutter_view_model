// @author luwenjie on 2025/3/25 17:00:38

import 'package:flutter/foundation.dart';
import 'package:view_model/src/get_instance/store.dart';
import 'package:view_model/src/log.dart';

import '../view_model/view_model.dart';

/// Dependency tracker for ViewModels
/// Used to collect and manage dependency relationships between ViewModels
class DependencyTracker extends ViewModelLifecycle {
  static final DependencyTracker _instance = DependencyTracker._();

  static DependencyTracker get instance => _instance;

  DependencyTracker._();

  /// Mapping from Widget ID to ViewModel types
  final Map<String, Set<String>> _watcherToViewModels = {};

  /// Mapping from ViewModel instance to detailed information
  final Map<String, ViewModelInfo> _viewModelInfos = {};

  /// Mapping from ViewModel type to instance list
  final Map<String, Set<String>> _typeToInstances = {};

  /// Listeners for dependency relationship changes
  final List<VoidCallback> _listeners = [];

  /// Get all dependency relationship data
  DependencyGraph get dependencyGraph {
    return DependencyGraph(
      watcherToViewModels: Map.unmodifiable(_watcherToViewModels),
      viewModelInfos: Map.unmodifiable(_viewModelInfos),
      typeToInstances: Map.unmodifiable(_typeToInstances),
    );
  }

  /// Add dependency relationship change listener
  VoidCallback addListener(VoidCallback listener) {
    _listeners.add(listener);
    return () => _listeners.remove(listener);
  }

  /// Notify listeners that dependency relationships have changed
  void _notifyListeners() {
    for (final listener in _listeners) {
      try {
        listener();
      } catch (e) {
        viewModelLog('DependencyTracker listener error: $e');
      }
    }
  }

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

  /// Generate unique instance identifier
  String _getInstanceId(ViewModel viewModel, InstanceArg arg) {
    return '${viewModel.runtimeType}_${arg.key}_${viewModel.hashCode}';
  }

  /// Clear all tracking data
  void clear() {
    _watcherToViewModels.clear();
    _viewModelInfos.clear();
    _typeToInstances.clear();
    _notifyListeners();
  }

  /// Get statistics information
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

/// ViewModel instance information
class ViewModelInfo {
  final String instanceId;
  final String typeName;
  final String? key;
  final String? tag;
  final DateTime createTime;
  final Set<String> watchers;
  final bool isDisposed;
  final DateTime? disposeTime;

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

/// Dependency graph data
class DependencyGraph {
  final Map<String, Set<String>> watcherToViewModels;
  final Map<String, ViewModelInfo> viewModelInfos;
  final Map<String, Set<String>> typeToInstances;

  const DependencyGraph({
    required this.watcherToViewModels,
    required this.viewModelInfos,
    required this.typeToInstances,
  });

  /// Get ViewModel list bound to specified watcher
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

  /// Get all instances of specified type
  List<ViewModelInfo> getInstancesOfType(String typeName) {
    final instanceIds = typeToInstances[typeName] ?? {};
    return instanceIds
        .map((id) => viewModelInfos[id])
        .where((info) => info != null)
        .cast<ViewModelInfo>()
        .toList();
  }
}

/// Dependency relationship statistics
class DependencyStats {
  final int activeInstances;
  final int sharedInstances;
  final int orphanedInstances;
  final int totalWatchers;
  final int viewModelTypes;
  final int disposedInstances;

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
