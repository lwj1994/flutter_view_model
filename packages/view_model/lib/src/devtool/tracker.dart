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
import 'package:view_model/src/view_model/config.dart';
import 'package:view_model/src/view_model/view_model.dart';

const _notProvided = Object();

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
  final Map<String, Set<String>> _bindingIds = {};

  /// Maps binding IDs to their lifecycle and ownership metadata.
  ///
  /// Unlike [_bindingIds], this registry also contains bindings that currently
  /// have no ViewModel edge. It therefore provides the complete binding node
  /// list required by DevTools instead of forcing the UI to infer nodes from
  /// active relationships.
  final Map<String, BindingInfo> _bindingInfos = {};

  /// Weakly associates a live ViewModel object with its diagnostics ID.
  ///
  /// An [Expando] avoids retaining ViewModel generations solely for linking
  /// their internal dependency bindings in DevTools.
  Expando<String> _viewModelInstanceIds =
      Expando<String>('view_model_instance_ids');

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
      watcherToViewModels: Map.unmodifiable(_bindingIds),
      bindingInfos: Map.unmodifiable(_bindingInfos),
      viewModelInfos: Map.unmodifiable(_viewModelInfos),
      typeToInstances: Map.unmodifiable(_typeToInstances),
    );
  }

  /// Registers a binding node independently from its ViewModel edges.
  ///
  /// [parentViewModel] is supplied for an internal dependency binding. The
  /// relationship may initially be unresolved when the binding is created in
  /// a parent constructor; [onCreate] fills in the parent generation ID once
  /// that parent has entered the managed lifecycle.
  void registerBinding({
    required String bindingId,
    required String name,
    required bool isDependencyBinding,
    ViewModel? parentViewModel,
  }) {
    final existing = _bindingInfos[bindingId];
    final parentViewModelId =
        parentViewModel == null ? null : _viewModelInstanceIds[parentViewModel];
    final kind = isDependencyBinding ? 'dependency' : 'root';
    final parentType = parentViewModel?.runtimeType.toString();

    final next = existing == null
        ? BindingInfo(
            bindingId: bindingId,
            name: name,
            kind: kind,
            createTime: DateTime.now(),
            parentViewModelId: parentViewModelId,
            parentViewModelType: parentType,
          )
        : existing.copyWith(
            name: name,
            kind: kind,
            parentViewModelId: parentViewModelId ?? existing.parentViewModelId,
            parentViewModelType: parentType ?? existing.parentViewModelType,
          );

    if (existing != null && existing.hasSameData(next)) return;
    _bindingInfos[bindingId] = next;
    _notifyListeners();
  }

  /// Marks a known binding as disposed while retaining its history.
  ///
  /// A dependency binding whose parent never completed creation is removed
  /// instead. This keeps failed construction transactions from leaving
  /// parentless virtual nodes in DevTools.
  void disposeBinding(String bindingId) {
    final info = _bindingInfos[bindingId];
    if (info == null || info.isDisposed) return;
    if (info.kind == 'dependency' && info.parentViewModelId == null) {
      _bindingInfos.remove(bindingId);
    } else {
      _bindingInfos[bindingId] = info.copyWith(
        isDisposed: true,
        disposeTime: DateTime.now(),
      );
    }
    _notifyListeners();
  }

  void _ensureUnknownBinding(String bindingId) {
    _bindingInfos.putIfAbsent(
      bindingId,
      () => BindingInfo(
        bindingId: bindingId,
        name: bindingId,
        kind: 'unknown',
        createTime: DateTime.now(),
      ),
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

  /// Notifies all registered listeners that dependency
  /// relationships have changed.
  ///
  /// This method is called internally whenever the dependency
  /// graph is modified.
  /// Listeners are called safely with error handling to prevent one failing
  /// listener from affecting others.
  void _notifyListeners() {
    final listeners = List<VoidCallback>.of(_listeners);
    for (final listener in listeners) {
      if (!_listeners.contains(listener)) continue;
      try {
        listener();
      } catch (e, stack) {
        reportViewModelError(
            e, stack, ErrorType.listener, 'DependencyTracker listener error');
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

    _viewModelInstanceIds[viewModel] = instanceId;

    _viewModelInfos[instanceId] = ViewModelInfo(
      instanceId: instanceId,
      typeName: typeName,
      key: arg.key,
      tag: arg.tag?.toString(),
      createTime: DateTime.now(),
      watchers: {},
      owners: viewModel.refHandler.owners.map((owner) => owner.id).toList(),
      primaryOwner: viewModel.refHandler.primaryOwner?.id,
    );

    // The handler owns this callback and clears it on disposal. The callback
    // captures only the tracker and the string instance ID, so tracking owner
    // changes does not retain the ViewModel or any ViewModelBinding.
    viewModel.refHandler.addOwnerChangeListener(
      (owners, previousPrimaryOwner, primaryOwner) {
        _updateOwners(
          instanceId,
          owners: owners,
          previousPrimaryOwner: previousPrimaryOwner,
          primaryOwner: primaryOwner,
        );
      },
    );

    _typeToInstances.putIfAbsent(typeName, () => {}).add(instanceId);

    final dependencyBinding = viewModel.dependencyBindingIfCreated;
    if (dependencyBinding != null) {
      registerBinding(
        bindingId: dependencyBinding.id,
        name: dependencyBinding.getName(),
        isDependencyBinding: true,
        parentViewModel: viewModel,
      );
    }

    viewModelLog("📱 onCreated, $instanceId");

    _notifyListeners();
  }

  void _updateOwners(
    String instanceId, {
    required List<String> owners,
    required String? previousPrimaryOwner,
    required String? primaryOwner,
  }) {
    final info = _viewModelInfos[instanceId];
    if (info == null) return;

    var primaryOwnerHandoff = info.primaryOwnerHandoff;
    if (previousPrimaryOwner != null &&
        primaryOwner != null &&
        previousPrimaryOwner != primaryOwner) {
      primaryOwnerHandoff = PrimaryOwnerHandoff(
        from: previousPrimaryOwner,
        to: primaryOwner,
        occurredAt: DateTime.now(),
      );
    }

    _viewModelInfos[instanceId] = info.copyWith(
      owners: List<String>.unmodifiable(owners),
      primaryOwner: primaryOwner,
      primaryOwnerHandoff: primaryOwnerHandoff,
    );
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
  /// - [bindingId]: Unique identifier for the new watcher
  @override
  void onBind(ViewModel viewModel, InstanceArg arg, String bindingId) {
    final instanceId = _getInstanceId(viewModel, arg);
    final typeName = viewModel.runtimeType.toString();

    // Low-level/custom integrations can provide a binding ID without using a
    // ViewModelBinding object. Keep those edges visible with an explicit
    // fallback node; normal bindings will already have richer metadata.
    _ensureUnknownBinding(bindingId);

    // Update watcher -> viewModels mapping
    _bindingIds.putIfAbsent(bindingId, () => {}).add(typeName);

    // Update watchers in viewModel information
    final info = _viewModelInfos[instanceId];
    if (info != null) {
      _viewModelInfos[instanceId] = info.copyWith(
        watchers: {...info.watchers, bindingId},
      );
    }

    viewModelLog("🔗 onBind, bindingId: $bindingId, $instanceId");

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
  /// - [bindingId]: Unique identifier for the removed watcher
  @override
  void onUnbind(ViewModel viewModel, InstanceArg arg, String bindingId) {
    final instanceId = _getInstanceId(viewModel, arg);
    final typeName = viewModel.runtimeType.toString();

    // Remove from watcher -> viewModels mapping
    final viewModels = _bindingIds[bindingId];
    if (viewModels != null) {
      viewModels.remove(typeName);
      if (viewModels.isEmpty) {
        _bindingIds.remove(bindingId);
        if (_bindingInfos[bindingId]?.kind == 'unknown') {
          _bindingInfos.remove(bindingId);
        }
      }
    }

    // Remove watcher from viewModel information
    final info = _viewModelInfos[instanceId];
    if (info != null) {
      final newWatchers = Set<String>.from(info.watchers);
      newWatchers.remove(bindingId);
      _viewModelInfos[instanceId] = info.copyWith(watchers: newWatchers);
    }

    viewModelLog('🔌 onUnbind, bindingId: $bindingId $instanceId');
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
        owners: const <String>[],
        primaryOwner: null,
      );
    }

    // Clean up related watcher mappings
    if (info != null) {
      for (final watcherId in info.watchers) {
        final viewModels = _bindingIds[watcherId];
        if (viewModels != null) {
          viewModels.remove(typeName);
          if (viewModels.isEmpty) {
            _bindingIds.remove(watcherId);
            if (_bindingInfos[watcherId]?.kind == 'unknown') {
              _bindingInfos.remove(watcherId);
            }
          }
        }
      }
    }

    viewModelLog('🗑️ onDisposed, $instanceId');
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
  ///
  /// Uses `identityHashCode` for stable per‑instance identity even when
  /// `hashCode` is overridden. Includes readable `key` and `tag` values to
  /// help correlate instances in logs and DevTools.
  String _getInstanceId(ViewModel viewModel, InstanceArg arg) {
    final type = viewModel.runtimeType.toString();
    final vmId = identityHashCode(viewModel);
    final keyStr =
        arg.key == null ? 'null' : '${arg.key}#${identityHashCode(arg.key)}';
    final tagStr =
        arg.tag == null ? 'null' : '${arg.tag}#${identityHashCode(arg.tag)}';
    return '$type(hash: $vmId, key: $keyStr, tag: $tagStr)';
  }

  /// Clears all tracking data.
  ///
  /// This method removes all stored dependency information, including
  /// watcher relationships, ViewModel information, and type mappings.
  /// Useful for testing or when a complete reset is needed.
  ///
  /// Note: This will trigger listener notifications.
  void clear() {
    _bindingIds.clear();
    _bindingInfos.clear();
    _viewModelInfos.clear();
    _typeToInstances.clear();
    _viewModelInstanceIds = Expando<String>('view_model_instance_ids');
    _notifyListeners();
  }

  /// Resets all tracker state without notifying or retaining test listeners.
  void resetForTesting() {
    _bindingIds.clear();
    _bindingInfos.clear();
    _viewModelInfos.clear();
    _typeToInstances.clear();
    _viewModelInstanceIds = Expando<String>('view_model_instance_ids');
    _listeners.clear();
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
    final totalWatchers = _bindingIds.length;
    final activeBindings =
        _bindingInfos.values.where((info) => !info.isDisposed).length;
    final disposedBindings =
        _bindingInfos.values.where((info) => info.isDisposed).length;

    return DependencyStats(
      activeInstances: activeInstances,
      sharedInstances: sharedInstances,
      orphanedInstances: orphanedInstances,
      totalWatchers: totalWatchers,
      viewModelTypes: _typeToInstances.length,
      disposedInstances: disposedInstances,
      activeBindings: activeBindings,
      disposedBindings: disposedBindings,
    );
  }
}

/// DevTools metadata for one root or internal dependency binding.
///
/// Only scalar diagnostics data is retained. In particular, this object never
/// stores the binding or parent ViewModel itself, so historical graph entries
/// cannot extend either runtime lifetime.
class BindingInfo {
  /// Unique ID used by lifecycle callbacks and graph edges.
  final String bindingId;

  /// Human-readable binding name captured at registration.
  final String name;

  /// `root`, `dependency`, or `unknown` for low-level integrations.
  final String kind;

  /// Timestamp when this binding was first observed.
  final DateTime createTime;

  /// Parent ViewModel generation that owns this dependency binding.
  final String? parentViewModelId;

  /// Parent runtime type, also available before construction completes.
  final String? parentViewModelType;

  /// Whether the binding has completed its lifecycle.
  final bool isDisposed;

  /// Timestamp when the binding was disposed, if applicable.
  final DateTime? disposeTime;

  const BindingInfo({
    required this.bindingId,
    required this.name,
    required this.kind,
    required this.createTime,
    this.parentViewModelId,
    this.parentViewModelType,
    this.isDisposed = false,
    this.disposeTime,
  });

  BindingInfo copyWith({
    String? name,
    String? kind,
    Object? parentViewModelId = _notProvided,
    Object? parentViewModelType = _notProvided,
    bool? isDisposed,
    DateTime? disposeTime,
  }) {
    return BindingInfo(
      bindingId: bindingId,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      createTime: createTime,
      parentViewModelId: identical(parentViewModelId, _notProvided)
          ? this.parentViewModelId
          : parentViewModelId as String?,
      parentViewModelType: identical(parentViewModelType, _notProvided)
          ? this.parentViewModelType
          : parentViewModelType as String?,
      isDisposed: isDisposed ?? this.isDisposed,
      disposeTime: disposeTime ?? this.disposeTime,
    );
  }

  bool hasSameData(BindingInfo other) {
    return bindingId == other.bindingId &&
        name == other.name &&
        kind == other.kind &&
        createTime == other.createTime &&
        parentViewModelId == other.parentViewModelId &&
        parentViewModelType == other.parentViewModelType &&
        isDisposed == other.isDisposed &&
        disposeTime == other.disposeTime;
  }
}

/// The most recent transfer between two active primary owners.
///
/// Owner IDs are stored instead of binding objects to avoid extending binding
/// lifetimes through DevTools history.
class PrimaryOwnerHandoff {
  /// Binding ID that previously resolved nested dependencies.
  final String from;

  /// Binding ID that now resolves nested dependencies.
  final String to;

  /// Time at which the handoff occurred.
  final DateTime occurredAt;

  const PrimaryOwnerHandoff({
    required this.from,
    required this.to,
    required this.occurredAt,
  });
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
  final Object? key;

  /// Optional tag used when creating this ViewModel instance.
  final String? tag;

  /// Timestamp when this ViewModel was created.
  final DateTime createTime;

  /// Set of watcher IDs currently watching this ViewModel.
  final Set<String> watchers;

  /// Ordered binding IDs that currently own this ViewModel.
  final List<String> owners;

  /// Binding ID currently used to resolve nested dependencies.
  final String? primaryOwner;

  /// Most recent transfer between two active primary owners.
  final PrimaryOwnerHandoff? primaryOwnerHandoff;

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
    this.owners = const <String>[],
    this.primaryOwner,
    this.primaryOwnerHandoff,
    this.isDisposed = false,
    this.disposeTime,
  });

  /// Creates a copy of this ViewModelInfo with optionally updated fields.
  ///
  /// This method allows updating specific fields while keeping
  /// others unchanged.
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
    Object? key,
    String? tag,
    DateTime? createTime,
    Set<String>? watchers,
    List<String>? owners,
    Object? primaryOwner = _notProvided,
    Object? primaryOwnerHandoff = _notProvided,
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
      owners: owners ?? this.owners,
      primaryOwner: identical(primaryOwner, _notProvided)
          ? this.primaryOwner
          : primaryOwner as String?,
      primaryOwnerHandoff: identical(primaryOwnerHandoff, _notProvided)
          ? this.primaryOwnerHandoff
          : primaryOwnerHandoff as PrimaryOwnerHandoff?,
      isDisposed: isDisposed ?? this.isDisposed,
      disposeTime: disposeTime ?? this.disposeTime,
    );
  }

  @override
  String toString() {
    return 'ViewModelInfo(id: $instanceId, type: $typeName, key: $key, '
        'tag: $tag, watchers: ${watchers.length}, owners: ${owners.length}, '
        'primaryOwner: $primaryOwner, isDisposed: $isDisposed)';
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

  /// Maps every observed binding ID to its lifecycle and kind metadata.
  final Map<String, BindingInfo> bindingInfos;

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
    required this.bindingInfos,
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
/// - **Orphaned Instances**: Active ViewModels with no watchers
///   (potential leaks)
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

  /// Number of registered bindings that are currently active.
  final int activeBindings;

  /// Number of registered bindings retained as disposed history.
  final int disposedBindings;

  /// Total number of registered root, dependency, and fallback bindings.
  int get totalBindings => activeBindings + disposedBindings;

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
    this.activeBindings = 0,
    this.disposedBindings = 0,
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
  Active Bindings: $activeBindings
  Disposed Bindings: $disposedBindings
  ViewModel Types: $viewModelTypes''';
  }
}
