/// Instance storage and lifecycle management for ViewModels.
///
/// This file provides the core storage mechanism for ViewModel instances,
/// including caching, lifecycle management, watcher tracking, and automatic
/// disposal. It ensures efficient resource usage and proper cleanup.
///
/// @author luwenjie on 2025/3/25 12:14:48
library;

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:uuid/v4.dart';
import 'package:view_model/src/log.dart';

import 'manager.dart';

/// Type-specific storage for ViewModel instances.
///
/// This class manages all instances of a specific ViewModel type [T],
/// providing caching, lifecycle management, and automatic cleanup.
/// Each ViewModel type gets its own dedicated store instance.
///
/// Key features:
/// - Instance caching by key
/// - Automatic disposal when no watchers remain
/// - Creation time tracking for instance discovery
/// - Stream-based instance creation notifications
///
/// The store maintains a map of instances keyed by their unique identifiers
/// and automatically handles cleanup when instances are no longer needed.
class Store<T> {
  /// Stream controller for broadcasting instance creation events.
  final _streamController = StreamController<InstanceHandle<T>>.broadcast();

  /// Map of cached instances keyed by their unique identifiers.
  final Map<Object, InstanceHandle<T>> _instances = {};

  /// Finds the most recently created instance, optionally filtered by tag.
  ///
  /// This method searches through all cached instances and returns the one
  /// with the highest creation index (most recent). If a tag is specified,
  /// only instances with matching tags are considered.
  ///
  /// Parameters:
  /// - [tag]: Optional tag to filter instances by
  ///
  /// Returns the most recent [InstanceHandle] matching the criteria,
  /// or `null` if no instances exist or match the tag.
  ///
  /// Example:
  /// ```dart
  /// // Find most recent instance of any tag
  /// final recent = store.findNewlyInstance();
  ///
  /// // Find most recent instance with specific tag
  /// final tagged = store.findNewlyInstance(tag: 'user_profile');
  /// ```
  InstanceHandle<T>? findNewlyInstance({
    Object? tag,
  }) {
    if (_instances.isEmpty) return null;
    final l = _instances.values.toList();
    l.sort((InstanceHandle<T> a, InstanceHandle<T> b) {
      // desc
      return b.index.compareTo(a.index);
    });
    if (tag == null) {
      return l.firstOrNull;
    } else {
      for (final InstanceHandle<T> instance in l) {
        if (instance.arg.tag == tag) {
          return instance;
        }
      }
      return null;
    }
  }

  /// Sets up disposal listening for an instance handle.
  ///
  /// This method registers a listener on the instance handle to automatically
  /// remove it from the store when it's disposed. This ensures proper cleanup
  /// and prevents memory leaks.
  ///
  /// Parameters:
  /// - [notifier]: The instance handle to monitor for disposal
  void _listenDispose(InstanceHandle<T> notifier) {
    void onNotify() {
      switch (notifier.action) {
        case null:
          break;
        case InstanceAction.dispose:
          _instances.remove(notifier.arg.key);
          notifier.removeListener(onNotify);
          break;
        case InstanceAction.recreate:
          break;
      }
    }

    notifier.addListener(onNotify);
  }

  /// Gets or creates an instance handle based on the factory configuration.
  ///
  /// This is the core method for instance management. It handles both retrieval
  /// of existing cached instances and creation of new ones. The method also
  /// manages watcher registration for lifecycle tracking.
  ///
  /// Process:
  /// 1. Generate or use provided key for instance identification
  /// 2. Check cache for existing instance with the key
  /// 3. If found, optionally add new watcher and return cached instance
  /// 4. If not found, create new instance using factory builder
  /// 5. Cache the new instance and set up disposal monitoring
  ///
  /// Parameters:
  /// - [factory]: Factory configuration containing builder and arguments
  ///
  /// Returns an [InstanceHandle] for the requested instance.
  ///
  /// Throws [StateError] if no cached instance exists and no builder is provided.
  InstanceHandle<T> getNotifier({required InstanceFactory<T> factory}) {
    final realKey = factory.arg.key ?? const UuidV4().generate();
    final watchId = factory.arg.watchId;
    final arg = factory.arg.copyWith(
      key: realKey,
    );
    // cache
    if (_instances.containsKey(realKey) && _instances[realKey] != null) {
      final notifier = _instances[realKey]!;
      final newWatcher =
          watchId != null && !notifier.watchIds.contains(watchId);
      if (newWatcher) {
        notifier.addNewWatcher(watchId);
      }
      return notifier;
    }

    if (factory.builder == null) {
      throw StateError("factory == null and cache is null");
    }

    // create new instance
    final instance = factory.builder!();

    int maxIndex = -1;
    for (final e in _instances.values) {
      if (e.index > maxIndex) {
        maxIndex = e.index;
      }
    }
    final create = InstanceHandle<T>(
      instance: instance,
      arg: arg,
      factory: factory.builder!,
      index: maxIndex + 1,
    );
    _instances[realKey] = create;
    _streamController.add(create);
    _listenDispose(create);
    return create;
  }

  /// Recreates an existing instance with optional custom builder.
  ///
  /// This method finds the instance handle for the given instance and
  /// triggers its recreation. The new instance will replace the old one
  /// while maintaining the same handle and watcher relationships.
  ///
  /// Parameters:
  /// - [t]: The existing instance to recreate
  /// - [builder]: Optional custom builder for the new instance
  ///
  /// Returns the newly created instance of type [T].
  T recreate(
    T t, {
    T Function()? builder,
  }) {
    final find = _instances.values.where((e) => e.instance == t).first;
    return find.recreate(builder: builder);
  }
}

/// Handle for managing a ViewModel instance and its lifecycle.
///
/// This class wraps a ViewModel instance and provides lifecycle management,
/// watcher tracking, and recreation capabilities. It acts as a proxy between
/// the store and the actual ViewModel instance.
///
/// Key responsibilities:
/// - Instance lifecycle management (creation, disposal, recreation)
/// - Watcher registration and removal
/// - Automatic disposal when no watchers remain
/// - Notification of lifecycle events
///
/// The handle uses [ChangeNotifier] to notify listeners of important events
/// like disposal and recreation.
class InstanceHandle<T> with ChangeNotifier {
  /// Arguments used for instance creation and identification.
  final InstanceArg arg;

  /// List of watcher IDs currently watching this instance.
  final List<String> watchIds = List.empty(growable: true);

  /// Factory function for creating new instances of this type.
  final T Function() factory;

  /// Creation index for ordering instances by creation time.
  final int index;

  /// Gets the current ViewModel instance.
  ///
  /// Throws if the instance has been disposed.
  T get instance => _instance!;

  /// The actual ViewModel instance (null when disposed).
  late T? _instance;

  /// Creates a new instance handle.
  ///
  /// Parameters:
  /// - [instance]: The ViewModel instance to wrap
  /// - [arg]: Instance arguments for identification
  /// - [index]: Creation order index
  /// - [factory]: Factory function for recreation
  InstanceHandle({
    required T instance,
    required this.arg,
    required this.index,
    required this.factory,
  }) : _instance = instance {
    onCreate(arg);
  }

  /// Adds a watcher to this instance.
  ///
  /// This method registers a new watcher ID and notifies the instance
  /// if it implements [InstanceLifeCycle]. Duplicate or null IDs are ignored.
  ///
  /// Parameters:
  /// - [id]: The watcher ID to add (ignored if null or already exists)
  void _addWatcher(String? id) {
    if (watchIds.contains(id) || id == null) return;
    watchIds.add(id);
    if (_instance is InstanceLifeCycle) {
      (_instance as InstanceLifeCycle).onAddWatcher(arg, id);
    }
  }

  /// Removes a watcher from this instance.
  ///
  /// This method unregisters a watcher ID and notifies the instance
  /// if it implements [InstanceLifeCycle]. If no watchers remain after
  /// removal, the instance is automatically recycled.
  ///
  /// Parameters:
  /// - [id]: The watcher ID to remove
  void removeWatcher(String id) {
    if (watchIds.remove(id)) {
      if (_instance is InstanceLifeCycle) {
        (_instance as InstanceLifeCycle).onRemoveWatcher(arg, id);
      }
    }
    if (watchIds.isEmpty) {
      recycle();
    }
  }

  /// Current action being performed on this instance.
  InstanceAction? _action;

  /// Gets the current action being performed on this instance.
  ///
  /// Returns the current [InstanceAction] or null if no action is in progress.
  InstanceAction? get action => _action;

  /// Disposes this instance and triggers cleanup.
  ///
  /// This method marks the instance for disposal, notifies listeners,
  /// and calls the disposal lifecycle methods. The instance becomes
  /// unusable after this call.
  void recycle() {
    _action = InstanceAction.dispose;
    notifyListeners();
    onDispose();
  }

  /// Recreates the instance with optional custom builder.
  ///
  /// This method disposes the current instance and creates a new one,
  /// either using the provided builder or the original factory function.
  /// All watcher relationships are preserved.
  ///
  /// Parameters:
  /// - [builder]: Optional custom builder for the new instance
  ///
  /// Returns the newly created instance.
  T recreate({
    T Function()? builder,
  }) {
    onDispose();
    _instance = (builder?.call()) ?? factory.call();
    onCreate(arg);
    _action = InstanceAction.recreate;
    notifyListeners();
    return instance;
  }

  @override
  String toString() {
    return "InstanceHandle<$T>(index=$index, $arg, watchIds=$watchIds)";
  }

  /// Handles instance creation lifecycle.
  ///
  /// This method is called when the instance is first created. It notifies
  /// the instance if it implements [InstanceLifeCycle] and adds the initial
  /// watcher if provided.
  ///
  /// Parameters:
  /// - [arg]: Instance arguments containing initial watcher ID
  void onCreate(InstanceArg arg) {
    if (_instance is InstanceLifeCycle) {
      (_instance as InstanceLifeCycle).onCreate(arg);
    }
    _addWatcher(arg.watchId);
  }

  /// Adds a new watcher to this instance.
  ///
  /// This is a public method for adding watchers after instance creation.
  ///
  /// Parameters:
  /// - [id]: The watcher ID to add
  void addNewWatcher(String id) {
    _addWatcher(id);
  }

  /// Safely calls the instance's disposal method.
  ///
  /// This method attempts to call the onDispose lifecycle method if the
  /// instance implements [InstanceLifeCycle]. Errors are logged but don't
  /// prevent the disposal process.
  void _tryCallInstanceDispose() {
    if (_instance is InstanceLifeCycle) {
      try {
        (_instance as InstanceLifeCycle).onDispose(arg);
      } catch (e) {
        viewModelLog("${_instance.runtimeType} onDispose error $e");
      }
    }
  }

  /// Handles instance disposal cleanup.
  ///
  /// This method calls the instance's disposal lifecycle method,
  /// clears all watchers, and nullifies the instance reference.
  void onDispose() {
    _tryCallInstanceDispose();
    _instance = null;
    watchIds.clear();
    _instance = null;
  }
}

/// Actions that can be performed on ViewModel instances.
///
/// These actions are used to track the current state of instance operations
/// and notify listeners of important lifecycle events.
enum InstanceAction {
  /// The instance is being disposed and will become unusable.
  dispose,

  /// The instance is being recreated with a new instance object.
  recreate,
}

/// Interface for ViewModel lifecycle management.
///
/// ViewModels can implement this interface to receive notifications
/// about their lifecycle events, including creation, watcher changes,
/// and disposal.
///
/// This interface enables ViewModels to:
/// - Initialize resources on creation
/// - Track their usage through watcher management
/// - Clean up resources on disposal
/// - React to dependency changes
abstract interface class InstanceLifeCycle {
  /// Called when the ViewModel instance is created.
  ///
  /// Parameters:
  /// - [arg]: Instance arguments used for creation
  void onCreate(InstanceArg arg);

  /// Called when a new watcher starts watching this ViewModel.
  ///
  /// Parameters:
  /// - [arg]: Instance arguments
  /// - [newWatchId]: ID of the new watcher
  void onAddWatcher(InstanceArg arg, String newWatchId);

  /// Called when a watcher stops watching this ViewModel.
  ///
  /// Parameters:
  /// - [arg]: Instance arguments
  /// - [removedWatchId]: ID of the removed watcher
  void onRemoveWatcher(InstanceArg arg, String removedWatchId);

  /// Called when the ViewModel instance is being disposed.
  ///
  /// Parameters:
  /// - [arg]: Instance arguments
  void onDispose(InstanceArg arg);
}

/// Arguments for ViewModel instance creation and identification.
///
/// This class encapsulates the metadata needed to create, identify, and
/// manage ViewModel instances. It contains information about instance
/// keys, tags, and watcher relationships.
///
/// Key components:
/// - **key**: Unique identifier for instance caching
/// - **tag**: Logical grouping identifier for related instances
/// - **watchId**: Identifier for the component watching this instance
///
/// Example:
/// ```dart
/// // Create with specific key for caching
/// final arg = InstanceArg(key: 'user_profile');
///
/// // Create with tag for logical grouping
/// final taggedArg = InstanceArg(tag: 'dashboard_widgets');
///
/// // Create with watcher for lifecycle tracking
/// final watchedArg = InstanceArg(watchId: 'widget_123');
/// ```
class InstanceArg {
  /// Unique identifier for instance caching.
  ///
  /// When provided, this key is used to cache and retrieve instances.
  /// Multiple requests with the same key will return the same instance.
  /// If null, a UUID will be generated automatically.
  final Object? key;

  /// Logical grouping identifier for related instances.
  ///
  /// Tags can be used to group related instances or find instances
  /// that serve similar purposes. Unlike keys, multiple instances
  /// can share the same tag.
  final Object? tag;

  /// Identifier for the component watching this instance.
  ///
  /// This ID is used for lifecycle tracking and automatic cleanup.
  /// When the watcher is disposed, the instance can be automatically
  /// cleaned up if no other watchers remain.
  final String? watchId;

//<editor-fold desc="Data Methods">
  /// Creates new instance arguments.
  ///
  /// Parameters:
  /// - [key]: Unique identifier for caching (optional)
  /// - [tag]: Logical grouping identifier (optional)
  /// - [watchId]: Watcher identifier for lifecycle tracking (optional)
  const InstanceArg({
    this.key,
    this.tag,
    this.watchId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InstanceArg &&
          runtimeType == other.runtimeType &&
          key == other.key &&
          tag == other.tag &&
          watchId == other.watchId);

  @override
  int get hashCode => key.hashCode ^ tag.hashCode ^ watchId.hashCode;

  @override
  String toString() {
    return 'InstanceArg{' ' key: $key,' ' tag: $tag,' ' watchId: $watchId,' '}';
  }

  InstanceArg copyWith({
    Object? key,
    Object? tag,
    String? watchId,
  }) {
    return InstanceArg(
      key: key ?? this.key,
      tag: tag ?? this.tag,
      watchId: watchId ?? this.watchId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'key': key,
      'tag': tag,
      'watchId': watchId,
    };
  }

  factory InstanceArg.fromMap(Map<String, dynamic> map) {
    return InstanceArg(
      key: map['key'],
      tag: map['tag'] as Object,
      watchId: map['watchId'] as String,
    );
  }

//</editor-fold>
}
