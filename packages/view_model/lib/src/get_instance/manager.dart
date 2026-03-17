/// Instance management system for ViewModel lifecycle control.
///
/// This file provides the core instance management functionality
/// for ViewModels,
/// including creation, caching, recreation, and binding management. The system
/// ensures efficient resource usage and proper lifecycle management.
///
/// @author luwenjie on 2025/3/25 12:23:33
library;

import 'package:flutter/foundation.dart';
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
/// ViewModel type and handles binding relationships.
///
/// Key responsibilities:
/// - ViewModel instance creation and caching
/// - Binding registration and management
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
    final store = _stores[T];
    if (store is! Store<T>) {
      throw ViewModelError("Cannot recreate $T instance. Store not found.");
    }
    return store.recreate(
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
    final cached = _stores[T];
    if (cached is Store<T>) {
      return cached;
    }

    late final Store<T> created;
    created = Store<T>(
      onStoreEmpty: () {
        final current = _stores[T];
        if (!identical(current, created) || !created.isEmpty) return;
        _stores.remove(T);
        created.dispose();
      },
    );
    _stores[T] = created;
    return created;
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
    } on ViewModelError {
      // Expected: instance not found, return null as documented.
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
  /// - Adding bindings to existing instances
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
      final bindingId = factory?.arg.bindingId;
      final tag = factory?.arg.tag;
      // find newly T instance
      final find = _getStore<T>().findNewlyInstance(
        tag: tag,
      );
      if (find == null) {
        throw ViewModelError("no $T instance found");
      }

      // if bindingId is not null, add binding
      if (bindingId != null) {
        final factory = InstanceFactory<T>(
            arg: InstanceArg(
          bindingId: bindingId,
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

  List<InstanceHandle<T>> getNotifiersByTag<T>(Object tag) {
    if (T == dynamic) {
      throw ViewModelError("T is dynamic");
    }
    return _getStore<T>().getInstancesByTag(tag);
  }

  @visibleForTesting
  int get debugStoreCount => _stores.length;

  @visibleForTesting
  bool debugHasStoreFor<T>() => _stores[T] != null;
}

/// Factory configuration for ViewModel instance creation and retrieval.
///
/// This class encapsulates the configuration needed to create or retrieve
/// ViewModel instances, including custom builder functions and instance
/// arguments like keys, tags, and binding IDs.
///
/// The factory supports various creation patterns:
/// - Custom instance creation with builder functions
/// - Instance retrieval by key or tag
/// - Binding registration for lifecycle management
///
/// Example:
/// ```dart
/// // Create with custom builder
/// final factory = InstanceFactory<MyViewModel>(
///   builder: () => MyViewModel(customData),
///   arg: InstanceArg(key: 'custom'),
/// );
///
/// // Create for binding only
/// final bindingFactory = InstanceFactory.binding(bindingId: 'widget123');
/// ```
class InstanceFactory<T> {
  /// Optional builder function for creating new instances.
  ///
  /// If provided, this function will be called to create new instances
  /// of the ViewModel. If null, the default constructor will be used.
  final T Function()? builder;

  /// Arguments for instance creation and identification.
  ///
  /// Contains metadata like key, tag, and binding ID that help identify
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

  /// Creates a factory specifically for binding to an existing instance.
  ///
  /// This factory constructor is used when you want to add a binding
  /// to an existing ViewModel instance without creating a new one.
  ///
  /// Parameters:
  /// - [bindingId]: Unique identifier for the binding
  ///
  /// Returns a new [InstanceFactory] configured for binding.
  factory InstanceFactory.binding({required String bindingId}) {
    return InstanceFactory(
      arg: InstanceArg(
        bindingId: bindingId,
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
