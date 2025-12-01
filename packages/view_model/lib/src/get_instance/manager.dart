/// Instance management system for ViewModel lifecycle control.
///
/// This file provides the core instance management functionality
/// for ViewModels,
/// including creation, caching, recreation, and watcher management. The system
/// ensures efficient resource usage and proper lifecycle management.
///
/// @author luwenjie on 2025/3/25 12:23:33
library;

import 'package:view_model/src/view_model/state_store.dart';

import 'store.dart';

/// Global instance manager singleton.
///
/// This is the main entry point for ViewModel instance management throughout
/// the application. It provides a centralized way to access the instance
/// management functionality.
final instanceManager = InstanceManager._get();

/// Central manager for ViewModel instance lifecycle.
///
/// This singleton class manages the creation, caching, and disposal
/// of ViewModel
/// instances across the application. It maintains separate stores for each
/// ViewModel type and handles watcher relationships.
///
/// Key responsibilities:
/// - ViewModel instance creation and caching
/// - Watcher registration and management
/// - Instance recreation and cleanup
/// - Type-safe instance retrieval
///
/// The manager uses a store-per-type architecture where each ViewModel type
/// has its own dedicated store for managing instances of that type.
class InstanceManager {
  InstanceManager._();

  /// Recreates an existing ViewModel instance.
  ///
  /// This method forces the recreation of a ViewModel instance, optionally
  /// using a custom builder function. The new instance will replace the
  /// existing one in the store.
  ///
  /// Parameters:
  /// - [t]: The existing instance to recreate
  /// - [builder]: Optional custom builder function for the new instance
  ///
  /// Returns the newly created instance of type [T].
  T recreate<T>(
    T t, {
    T Function()? builder,
  }) {
    final Store<T> s = _stores[T];
    return s.recreate(
      t,
      builder: builder,
    );
  }

  /// Factory constructor that returns the singleton instance.
  factory InstanceManager._get() => _instance;

  /// The singleton instance of the manager.
  static final InstanceManager _instance = InstanceManager._();

  /// Map storing type-specific stores for ViewModel instances.
  ///
  /// Each ViewModel type gets its own dedicated store for managing
  /// instances of that specific type.
  final Map<Type, dynamic> _stores = {};

  /// Gets or creates a store for the specified type.
  ///
  /// This method ensures that each ViewModel type has a dedicated store
  /// for managing its instances. Stores are created lazily when first accessed.
  ///
  /// Returns the [Store] instance for type [T].
  Store<T> _getStore<T>() {
    Store<T>? s = _stores[T];
    s ??= Store<T>();
    _stores[T] = s;
    return s;
  }

  /// Gets a ViewModel instance directly.
  ///
  /// This is a convenience method that retrieves a ViewModel instance
  /// without exposing the underlying instance handle. It delegates to
  /// [getNotifier] and returns the instance from the handle.
  ///
  /// Parameters:
  /// - [factory]: Optional factory for creating or finding the instance
  ///
  /// Returns the ViewModel instance of type [T].
  ///
  /// Throws [ViewModelError] if no instance is found and cannot be created.
  T get<T>({
    InstanceFactory<T>? factory,
  }) {
    return getNotifier(factory: factory).instance;
  }

  T? maybeGet<T>({
    InstanceFactory<T>? factory,
  }) {
    try {
      return get(factory: factory);
    } catch (e) {
      //
      return null;
    }
  }

  /// Gets an instance handle for a ViewModel.
  ///
  /// This is the core method for retrieving ViewModel instances. It handles
  /// both creation of new instances and retrieval of existing ones based on
  /// the provided factory configuration.
  ///
  /// The method supports several scenarios:
  /// - Creating new instances with custom builders
  /// - Finding existing instances by key or tag
  /// - Adding watchers to existing instances
  /// - Automatic instance discovery when no specific factory is provided
  ///
  /// Parameters:
  /// - [factory]: Factory configuration for instance creation/retrieval
  ///
  /// Returns an [InstanceHandle] for the ViewModel instance.
  ///
  /// Throws [ViewModelError] if:
  /// - [T] is dynamic (type must be specified)
  /// - No instance is found and cannot be created
  InstanceHandle<T> getNotifier<T>({
    InstanceFactory<T>? factory,
  }) {
    if (T == dynamic) {
      throw ViewModelError("T is dynamic");
    }
    if (factory == null || factory.isEmpty()) {
      final bindedVefId = factory?.arg.vefId;
      final tag = factory?.arg.tag;
      // find newly T instance
      final find = _getStore<T>().findNewlyInstance(
        tag: tag,
      );
      if (find == null) {
        throw ViewModelError("no $T instance found");
      }

      // if watchId is not null, add watcher
      if (bindedVefId != null) {
        final factory = InstanceFactory<T>(
            arg: InstanceArg(
          vefId: bindedVefId,
          key: find.arg.key,
          tag: find.arg.tag,
        ));
        return _getStore<T>().getNotifier(factory: factory);
      } else {
        return find;
      }
    } else {
      return _getStore<T>().getNotifier(
        factory: factory,
      );
    }
  }
}

/// Factory configuration for ViewModel instance creation and retrieval.
///
/// This class encapsulates the configuration needed to create or retrieve
/// ViewModel instances, including custom builder functions and instance
/// arguments like keys, tags, and watcher IDs.
///
/// The factory supports various creation patterns:
/// - Custom instance creation with builder functions
/// - Instance retrieval by key or tag
/// - Watcher registration for lifecycle management
///
/// Example:
/// ```dart
/// // Create with custom builder
/// final factory = InstanceFactory<MyViewModel>(
///   builder: () => MyViewModel(customData),
///   arg: InstanceArg(key: 'custom'),
/// );
///
/// // Create for watching only
/// final watchFactory = InstanceFactory.watch(watchId: 'widget123');
/// ```
class InstanceFactory<T> {
  /// Optional builder function for creating new instances.
  ///
  /// If provided, this function will be called to create new instances
  /// of the ViewModel. If null, the default constructor will be used.
  final T Function()? builder;

  /// Arguments for instance creation and identification.
  ///
  /// Contains metadata like key, tag, and watcher ID that help identify
  /// and manage the instance lifecycle.
  final InstanceArg arg;

  /// Checks if this factory is empty (no builder and no key).
  ///
  /// An empty factory typically indicates a request to find an existing
  /// instance rather than create a new one.
  ///
  /// Returns `true` if both builder and key are null.
  bool isEmpty() {
    return builder == null && arg.key == null;
  }

  /// Creates a factory specifically for watching an existing instance.
  ///
  /// This factory constructor is used when you want to add a watcher
  /// to an existing ViewModel instance without creating a new one.
  ///
  /// Parameters:
  /// - [vefId]: Unique identifier for the watcher
  ///
  /// Returns a new [InstanceFactory] configured for watching.
  factory InstanceFactory.vef({required String vefId}) {
    return InstanceFactory(
      arg: InstanceArg(
        vefId: vefId,
      ),
    );
  }

  /// Creates a new instance factory.
  ///
  /// Parameters:
  /// - [builder]: Optional function to create new instances
  /// - [arg]: Instance arguments (defaults to empty InstanceArg)
  InstanceFactory({
    this.builder,
    this.arg = const InstanceArg(),
  });

  /// Creates a copy of this factory with optionally updated fields.
  ///
  /// This method is useful for modifying factory configuration while
  /// preserving existing settings.
  ///
  /// Parameters:
  /// - [factory]: New builder function (optional)
  /// - [arg]: New instance arguments (optional)
  ///
  /// Returns a new [InstanceFactory] with updated configuration.
  InstanceFactory<T> copyWith({
    T Function()? factory,
    InstanceArg? arg,
  }) {
    return InstanceFactory<T>(
      builder: factory ?? builder,
      arg: arg ?? this.arg,
    );
  }

  @override
  String toString() {
    return '$T InstanceFactory{arg: $arg}';
  }
}
