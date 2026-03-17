/// Instance storage and lifecycle management for ViewModels.
///
/// This file provides the core storage mechanism for ViewModel instances,
/// including caching, lifecycle management, binding tracking, and automatic
/// disposal. It ensures efficient resource usage and proper cleanup.
///
/// @author luwenjie on 2025/3/25 12:14:48
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:view_model/src/log.dart';
import 'package:view_model/src/view_model/state_store.dart';
import 'package:view_model/src/view_model/config.dart';
import 'package:view_model/src/view_model/view_model.dart';

import 'manager.dart';

/// Sentinel value for distinguishing between "not provided" and "null" in
/// copyWith methods.
class _Undefined {
  const _Undefined();
}

/// Type-specific storage for ViewModel instances.
///
/// This class manages all instances of a specific ViewModel type [T],
/// providing caching, lifecycle management, and automatic cleanup.
/// Each ViewModel type gets its own dedicated store instance.
///
/// Key features:
/// - Instance caching by key
/// - Automatic disposal when no bindings remain
/// - Creation time tracking for instance discovery
/// - Stream-based instance creation notifications
///
/// The store maintains a map of instances keyed by their unique identifiers
/// and automatically handles cleanup when instances are no longer needed.
class Store<T> {
  Store({void Function()? onStoreEmpty}) : _onStoreEmpty = onStoreEmpty;

  final void Function()? _onStoreEmpty;

  /// Stream controller for broadcasting instance creation events.
  final _streamController = StreamController<InstanceHandle<T>>.broadcast();

  /// Map of cached instances keyed by their unique identifiers.
  final Map<Object, InstanceHandle<T>> _instances = {};
  bool _disposed = false;

  /// Monotonically increasing counter for instance creation ordering.
  int _nextIndex = 0;

  bool get isEmpty => _instances.isEmpty;

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
    if (_disposed) {
      throw ViewModelError("Store<$T> has been disposed.");
    }
    if (_instances.isEmpty) return null;
    final l = _instances.values.toList();
    l.sort((InstanceHandle<T> a, InstanceHandle<T> b) {
      // desc
      return b.index.compareTo(a.index);
    });
    if (tag == null) {
      return l.firstOrNull;
    } else {
      return getInstancesByTag(tag).firstOrNull;
    }
  }

  List<InstanceHandle<T>> getInstancesByTag(Object tag) {
    if (_disposed) {
      throw ViewModelError("Store<$T> has been disposed.");
    }
    if (_instances.isEmpty) return [];
    final List<InstanceHandle<T>> result = [];
    for (final handle in _instances.values) {
      if (handle.arg.tag == tag) {
        result.add(handle);
      }
    }
    result.sort((a, b) => b.index.compareTo(a.index));
    return result;
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
          if (_instances.isEmpty) {
            _onStoreEmpty?.call();
          }
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
  /// manages binding registration for lifecycle tracking.
  ///
  /// Process:
  /// 1. Generate or use provided key for instance identification
  /// 2. Check cache for existing instance with the key
  /// 3. If found, optionally add new binding and return cached instance
  /// 4. If not found, create new instance using factory builder
  /// 5. Cache the new instance and set up disposal monitoring
  ///
  /// Parameters:
  /// - [factory]: Factory configuration containing builder and arguments
  ///
  /// Returns an [InstanceHandle] for the requested instance.
  ///
  /// Throws [ViewModelError] if no cached instance exists and no
  /// builder is provided.
  InstanceHandle<T> getNotifier({required InstanceFactory<T> factory}) {
    if (_disposed) {
      throw ViewModelError("Store<$T> has been disposed.");
    }
    final realKey = factory.arg.key ?? Object();
    final bindingId = factory.arg.bindingId;
    final arg = factory.arg.copyWith(
      key: realKey,
    );
    // cache
    if (_instances.containsKey(realKey) && _instances[realKey] != null) {
      final notifier = _instances[realKey]!;
      final newBind = bindingId != null && !notifier.containsBinding(bindingId);
      if (newBind) {
        notifier.bind(bindingId);
      }
      return notifier;
    }

    if (factory.builder == null) {
      throw ViewModelError("${T} factory == null and cache is null");
    }

    // create new instance
    final instance = factory.builder!();

    final create = InstanceHandle<T>(
      instance: instance,
      arg: arg,
      factory: factory.builder!,
      index: _nextIndex++,
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
  /// while maintaining the same handle and binding relationships.
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
    if (_disposed) {
      throw ViewModelError("Store<$T> has been disposed.");
    }
    final find = _instances.values.firstWhere(
      (e) => e.instance == t,
      orElse: () => throw ViewModelError(
          "Cannot recreate ${T} instance. Instance not found in store."),
    );
    return find.recreate(builder: builder);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    // Dispose remaining handles to ensure lifecycle callbacks are called.
    // Each handle is wrapped in try-catch so one failure doesn't skip others.
    final handles = List<InstanceHandle<T>>.of(_instances.values);
    for (final handle in handles) {
      try {
        handle.onDispose();
      } catch (e, stack) {
        reportViewModelError(
            e, stack, ErrorType.dispose, 'Store<$T> handle dispose error');
      }
    }
    _instances.clear();
    _streamController.close();
  }
}

/// Handle for managing a ViewModel instance and its lifecycle.
///
/// This class wraps a ViewModel instance and provides lifecycle management,
/// binding tracking, and recreation capabilities. It acts as a proxy between
/// the store and the actual ViewModel instance.
///
/// Key responsibilities:
/// - Instance lifecycle management (creation, disposal, recreation)
/// - Binding registration and removal
/// - Automatic disposal when no bindings remain
/// - Notification of lifecycle events
///
/// The handle uses [ChangeNotifier] to notify listeners of important events
/// like disposal and recreation.
class InstanceHandle<T> with ChangeNotifier {
  /// Arguments used for instance creation and identification.
  final InstanceArg arg;

  /// List of binding IDs currently bound to this instance.
  final List<String> _bindingIds = List.empty(growable: true);

  /// Unmodifiable view of active binding IDs.
  List<String> get bindingIds => List.unmodifiable(_bindingIds);

  /// Returns true if [id] is in the active binding list.
  ///
  /// Prefer this over `bindingIds.contains(id)` to avoid allocating
  /// an unmodifiable list wrapper on every call.
  bool containsBinding(String id) => _bindingIds.contains(id);

  /// Factory function for creating new instances of this type.
  final T Function() factory;

  /// Creation index for ordering instances by creation time.
  final int index;

  /// Gets the current ViewModel instance.
  ///
  /// Throws [ViewModelError] if the instance has been disposed.
  T get instance {
    if (_instance == null) {
      throw ViewModelError("Cannot access $T instance after disposal.");
    }
    return _instance!;
  }

  /// The actual ViewModel instance (null when disposed).
  late T? _instance;
  bool _disposed = false;

  bool get isDisposed => _disposed;

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

  /// Adds a binding to this instance.
  ///
  /// This method registers a new binding ID and notifies the instance
  /// if it implements [InstanceLifeCycle]. Duplicate or null IDs are ignored.
  ///
  /// Parameters:
  /// - [id]: The binding ID to add (ignored if null or already exists)
  void bind(String? id) {
    if (_disposed || _bindingIds.contains(id) || id == null) return;
    _bindingIds.add(id);
    _notifyBind(id);
  }

  /// Removes a binding from this instance.
  ///
  /// This method unregisters a binding ID and notifies the instance
  /// if it implements [InstanceLifeCycle]. If no bindings remain after
  /// removal, the instance is automatically recycled.
  ///
  /// Parameters:
  /// - [id]: The binding ID to remove
  void unbind(String id) {
    if (_disposed) return;
    if (_bindingIds.remove(id)) {
      try {
        if (_instance is InstanceLifeCycle) {
          (_instance as InstanceLifeCycle).onUnbind(arg, id);
        }
      } catch (e, stack) {
        reportViewModelError(e, stack, ErrorType.lifecycle,
            '${_instance.runtimeType} onUnbind error');
      }
      if (_bindingIds.isEmpty) {
        _recycle();
      }
    }
  }

  /// Current action being performed on this instance.
  InstanceAction? _action;
  InstanceAction? _lastAction;

  /// Gets the current or most recent action on this instance.
  ///
  /// During a [notifyListeners] callback, returns the in-progress action
  /// (e.g. [InstanceAction.dispose] or [InstanceAction.recreate]).
  /// After the callback completes, [_action] is cleared to `null`.
  /// Once the handle is disposed, falls back to [_lastAction] so that
  /// late readers (e.g. Store's dispose listener) can still observe what
  /// happened.
  InstanceAction? get action => _action ?? (_disposed ? _lastAction : null);

  /// Disposes this instance and triggers cleanup.
  ///
  /// This method marks the instance for disposal, notifies listeners,
  /// and calls the disposal lifecycle methods. The instance becomes
  /// unusable after this call.
  void _recycle({bool force = false}) {
    if (arg.aliveForever && !force) return;
    _action = InstanceAction.dispose;
    _lastAction = _action;
    notifyListeners();
    _action = null;
    onDispose();
  }

  void unbindAll({bool force = false}) {
    if (_disposed) return;
    // Skip onUnbind callbacks and cleanup for aliveForever instances,
    // as they should retain their bindings.
    if (arg.aliveForever && !force) return;
    for (int i = 0; i < _bindingIds.length; i++) {
      try {
        if (_instance is InstanceLifeCycle) {
          (_instance as InstanceLifeCycle).onUnbind(arg, _bindingIds[i]);
        }
      } catch (e, stack) {
        reportViewModelError(e, stack, ErrorType.lifecycle,
            '${_instance.runtimeType} onUnbind error');
      }
    }
    _bindingIds.clear();
    _recycle(force: force);
  }

  /// Recreates the instance with optional custom builder.
  ///
  /// This method disposes the current instance and creates a new one,
  /// either using the provided builder or the original factory function.
  /// All binding relationships are preserved.
  ///
  /// Parameters:
  /// - [builder]: Optional custom builder for the new instance
  ///
  /// Returns the newly created instance.
  T recreate({
    T Function()? builder,
  }) {
    if (_disposed) {
      throw ViewModelError("Cannot recreate $T instance. Handle is disposed.");
    }
    final previous = _instance;
    if (previous == null) {
      throw ViewModelError(
          "Cannot recreate $T instance. Instance is disposed.");
    }
    final activeBindingIds = List<String>.of(_bindingIds);
    final recreated = (builder?.call()) ?? factory.call();
    _tryCallInstanceDispose(previous);
    _instance = recreated;
    _notifyCreate(arg);
    for (final bindingId in activeBindingIds) {
      _notifyBind(bindingId);
    }
    _action = InstanceAction.recreate;
    _lastAction = _action;
    notifyListeners();
    _action = null;
    return instance;
  }

  @override
  String toString() {
    return "InstanceHandle<$T>(index=$index, $arg, bindingIds=$bindingIds)";
  }

  /// Handles instance creation lifecycle.
  ///
  /// This method is called when the instance is first created. It notifies
  /// the instance if it implements [InstanceLifeCycle] and adds the initial
  /// binding if provided.
  ///
  /// Parameters:
  /// - [arg]: Instance arguments containing initial binding ID
  void onCreate(InstanceArg arg) {
    _notifyCreate(arg);
    bind(arg.bindingId);
  }

  void _notifyBind(String bindingId) {
    if (_instance is InstanceLifeCycle) {
      try {
        (_instance as InstanceLifeCycle).onBind(arg, bindingId);
      } catch (e, stack) {
        reportViewModelError(e, stack, ErrorType.lifecycle,
            '${_instance.runtimeType} onBind error');
      }
    }
  }

  void _notifyCreate(InstanceArg arg) {
    if (_instance is InstanceLifeCycle) {
      try {
        (_instance as InstanceLifeCycle).onCreate(arg);
      } catch (e, stack) {
        reportViewModelError(e, stack, ErrorType.lifecycle,
            '${_instance.runtimeType} onCreate error');
      }
    }
  }

  /// Safely calls the instance's disposal method.
  ///
  /// This method attempts to call the onDispose lifecycle method if the
  /// instance implements [InstanceLifeCycle]. Errors are logged but don't
  /// prevent the disposal process.
  void _tryCallInstanceDispose(Object? target) {
    if (target is InstanceLifeCycle) {
      try {
        target.onDispose(arg);
      } catch (e, stack) {
        reportViewModelError(e, stack, ErrorType.dispose,
            '${target.runtimeType} onDispose error');
      }
    }
  }

  /// Handles instance disposal cleanup.
  ///
  /// This method calls the instance's disposal lifecycle method,
  /// nullifies the instance reference, and disposes the ChangeNotifier.
  void onDispose() {
    if (_disposed) return;
    _disposed = true;
    _tryCallInstanceDispose(_instance);
    _instance = null;
    super.dispose();
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
/// about their lifecycle events, including creation, binding changes,
/// and disposal.
///
/// This interface enables ViewModels to:
/// - Initialize resources on creation
/// - Track their usage through binding management
/// - Clean up resources on disposal
/// - React to dependency changes
abstract interface class InstanceLifeCycle {
  /// Called when the ViewModel instance is created.
  ///
  /// Parameters:
  /// - [arg]: Instance arguments used for creation
  void onCreate(InstanceArg arg);

  /// Called when a new binding is added to this ViewModel.
  ///
  /// Parameters:
  /// - [arg]: Instance arguments
  /// - [bindingId]: ID of the new binding
  void onBind(InstanceArg arg, String bindingId);

  /// Called when a binding is removed from this ViewModel.
  ///
  /// Parameters:
  /// - [arg]: Instance arguments
  /// - [bindingId]: ID of the removed binding
  void onUnbind(InstanceArg arg, String bindingId);

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
/// keys, tags, and binding relationships.
///
/// Key components:
/// - **key**: Unique identifier for instance caching
/// - **tag**: Logical grouping identifier for related instances
/// - **bindingId**: Identifier for the component bound to this instance
///
/// Example:
/// ```dart
/// // Create with specific key for caching
/// final arg = InstanceArg(key: 'user_profile');
///
/// // Create with tag for logical grouping
/// final taggedArg = InstanceArg(tag: 'dashboard_widgets');
///
/// // Create with binding for lifecycle tracking
/// final boundArg = InstanceArg(bindingId: 'widget_123');
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

  /// Identifier for the component bound to this instance.
  ///
  /// This ID is used for lifecycle tracking and automatic cleanup.
  /// When the binding is disposed, the instance can be automatically
  /// cleaned up if no other bindings remain.
  final String? bindingId;

  /// Whether the instance should live forever (never be disposed).
  final bool aliveForever;

//<editor-fold desc="Data Methods">
  /// Creates new instance arguments.
  ///
  /// Parameters:
  /// - [key]: Unique identifier for instance caching (optional)
  /// - [tag]: Logical grouping identifier (optional)
  /// - [bindingId]: Binding identifier for lifecycle tracking (optional)
  /// - [aliveForever]: Whether the instance should live forever (optional,
  /// default: false)
  const InstanceArg({
    this.key,
    this.tag,
    this.bindingId,
    this.aliveForever = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InstanceArg &&
          runtimeType == other.runtimeType &&
          key == other.key &&
          tag == other.tag &&
          bindingId == other.bindingId &&
          aliveForever == other.aliveForever);

  @override
  int get hashCode =>
      key.hashCode ^ tag.hashCode ^ bindingId.hashCode ^ aliveForever.hashCode;

  @override
  String toString() {
    return 'InstanceArg( key: $key, tag: $tag, bindingId: $bindingId, '
        'aliveForever: $aliveForever)';
  }

  /// Creates a copy of this [InstanceArg] with optionally updated fields.
  ///
  /// This method uses a sentinel value pattern to distinguish between
  /// "not provided" and "explicitly set to null". This allows you to
  /// explicitly set fields to null when needed.
  ///
  /// Example:
  /// ```dart
  /// final arg = InstanceArg(key: 'myKey', tag: 'myTag');
  /// final updated = arg.copyWith(key: null); // Explicitly sets key to null
  /// ```
  InstanceArg copyWith({
    Object? key = const _Undefined(),
    Object? tag = const _Undefined(),
    Object? bindingId = const _Undefined(),
    bool? aliveForever,
  }) {
    return InstanceArg(
      key: identical(key, const _Undefined()) ? this.key : key,
      tag: identical(tag, const _Undefined()) ? this.tag : tag,
      bindingId: identical(bindingId, const _Undefined())
          ? this.bindingId
          : (bindingId as String?),
      aliveForever: aliveForever ?? this.aliveForever,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'key': key,
      'tag': tag,
      'bindingId': bindingId,
      'aliveForever': aliveForever,
    };
  }

  factory InstanceArg.fromMap(Map<String, dynamic> map) {
    return InstanceArg(
      key: map['key'],
      tag: map['tag'],
      bindingId: map['bindingId'] as String?,
      aliveForever: (map['aliveForever'] ?? false) as bool,
    );
  }

//</editor-fold>
}
