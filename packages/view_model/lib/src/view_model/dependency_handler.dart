// @author luwenjie on 2025/1/27 10:00:00

/// Dependency management handler for ViewModels.
///
/// This class encapsulates all dependency-related logic for ViewModels,
/// providing a clean separation of concerns and making the ViewModel class
/// more focused on its core responsibilities.
library;

import 'dart:async';

import 'package:meta/meta.dart' show internal;

import 'model.dart' as model;
import 'view_model.dart';

typedef DependencyResolver = T Function<T extends ViewModel>({
  required model.ViewModelDependencyConfig<T> dependency,
  bool listen,
});

const _resolverKey = #_viewModelDependencyResolver;

/// Runs the given [body] in a zone with the provided dependency [resolver].
/// This makes the resolver available to `DependencyHandler` instances created
/// within the zone.
R runWithResolver<R>(R Function() body, DependencyResolver resolver) {
  return runZoned(body, zoneValues: {_resolverKey: resolver});
}

/// Handler class responsible for managing ViewModel dependencies.
///
/// This class provides:
/// - Dependency configuration storage
/// - Dependency resolution through callbacks
/// - Clean separation of dependency logic from ViewModel core functionality
///
/// Example usage:
/// ```dart
/// class MyViewModel with ViewModel {
///   late final DependencyHandler _dependencyHandler;
///
///   @override
///   void onInit() {
///     _dependencyHandler = DependencyHandler();
///     final userService = _dependencyHandler.readViewModel<UserService>();
///   }
/// }
/// ```
@internal
class DependencyHandler {
  /// Callback function to resolve ViewModel dependencies.
  /// This is typically set by ViewModelStateMixin to delegate dependency resolution
  /// to the State that manages the ViewModel.
  @internal
  final List<DependencyResolver> dependencyResolvers = [];

  DependencyHandler();

  /// Sets the dependency resolver callback.
  ///
  /// This should only be called by ViewModelStateMixin or similar framework code.
  /// The resolver is responsible for creating or retrieving
  /// ViewModel instances.
  ///
  /// Parameters:
  /// - [resolver]: Function that resolves dependencies with listen parameter
  @internal
  void addDependencyResolver(
    DependencyResolver resolver,
  ) {
    if (!dependencyResolvers.contains(resolver)) {
      dependencyResolvers.add(resolver);
    }
  }

  @internal
  void removeDependencyResolver(
    DependencyResolver resolver,
  ) {
    dependencyResolvers.remove(resolver);
  }

  /// Clears the dependency resolver callback and all stored dependencies.
  ///
  /// This should be called when the ViewModel is no longer managed by a State
  /// to prevent memory leaks and ensure clean disposal.
  void dispose() {
    dependencyResolvers.clear();
  }

  /// Reads a dependency ViewModel from the current context.
  ///
  /// This method allows ViewModels to access other ViewModels as dependencies.
  /// The core logic is:
  /// 1. Create dependency configuration
  /// 2. Store the dependency config for tracking
  /// 3. If resolver is available, delegate to it
  /// 4. Otherwise, use static fallback method
  ///
  /// Parameters:
  /// - [key]: Optional key to identify a specific ViewModel instance
  /// - [tag]: Optional tag for ViewModel lookup
  /// - [factory]: Optional factory for creating the ViewModel if it doesn't exist
  ///
  /// Returns the requested ViewModel instance.
  T getViewModel<T extends ViewModel>({
    Object? key,
    Object? tag,
    ViewModelFactory<T>? factory,
    bool listen = false,
  }) {
    final resolver = dependencyResolvers.firstOrNull ??
        (Zone.current[_resolverKey] as DependencyResolver?);

    if (resolver == null) {
      throw StateError(
          'No dependency resolver available. ViewModel must be used within a Widget context');
    }
    // Create dependency configuration
    final dependencyConfig = model.ViewModelDependencyConfig<T>(
      config: model.ViewModelConfig(
        key: key,
        tag: tag,
        factory: factory,
      ),
    );
    // Check if there's a registered dependency resolver callback
    return resolver(
      dependency: dependencyConfig,
      listen: listen,
    );
  }

  /// Attempts to read a dependency ViewModel of type [T].
  ///
  /// Similar to [getViewModel] but returns `null` if the dependency is not found
  /// instead of throwing an exception. This is useful when you want to safely
  //
  /// check for optional dependencies without handling exceptions.
  ///
  /// Parameters:
  /// - [key]: Optional key to identify a specific ViewModel instance
  /// - [tag]: Optional tag for ViewModel lookup
  /// - [factory]: Optional factory for creating the ViewModel if it doesn't exist
  /// - [listen]: Whether to establish a listening relationship (default: false)
  ///
  /// Returns the requested ViewModel instance if found, otherwise `null`.
  ///
  /// Example:
  /// ```dart
  /// // Safe dependency access
  /// final authViewModel = dependencyHandler.maybeGetViewModel<AuthViewModel>();
  /// if (authViewModel != null) {
  ///   // Use the dependency
  ///   print('User is logged in: ${authViewModel.isLoggedIn}');
  /// }
  /// ```
  T? maybeGetViewModel<T extends ViewModel>({
    Object? key,
    Object? tag,
    ViewModelFactory<T>? factory,
    bool listen = false,
  }) {
    try {
      return getViewModel<T>(
        key: key,
        tag: tag,
        factory: factory,
        listen: listen,
      );
    } catch (e) {
      return null;
    }
  }

  /// Recycles a previously created ViewModel instance.
  ///
  /// This method allows ViewModels to be cached and reused,
  /// potentially improving performance by avoiding repeated creation.
  ///
  /// Parameters:
  /// - [viewModel]: The ViewModel instance to be recycled.
  ///
  void recycleViewModel<T extends ViewModel>(T viewModel) {
    //
    throw UnimplementedError("todo");
  }
}
