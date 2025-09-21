// @author luwenjie on 2025/1/27 10:00:00

/// Dependency management handler for ViewModels.
///
/// This class encapsulates all dependency-related logic for ViewModels,
/// providing a clean separation of concerns and making the ViewModel class
/// more focused on its core responsibilities.
library;


import 'model.dart' as model;
import 'view_model.dart';

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
class DependencyHandler {
  /// Callback function to resolve ViewModel dependencies.
  /// This is typically set by ViewModelStateMixin to delegate dependency resolution
  /// to the State that manages the ViewModel.
  T Function<T extends ViewModel>({
    required model.ViewModelDependencyConfig<T> dependency,
  })? _dependencyResolver;

  /// Checks if a dependency resolver is currently set.
  bool get hasResolver => _dependencyResolver != null;

  /// Sets the dependency resolver callback.
  ///
  /// This should only be called by ViewModelStateMixin or similar framework code.
  /// The resolver is responsible for actually creating or retrieving ViewModel instances.
  ///
  /// Parameters:
  /// - [resolver]: Function that resolves dependencies with listen parameter
  void setDependencyResolver(
    T Function<T extends ViewModel>({
      required model.ViewModelDependencyConfig<T> dependency,
    }) resolver,
  ) {
    _dependencyResolver = resolver;
  }

  /// Clears the dependency resolver callback and all stored dependencies.
  ///
  /// This should be called when the ViewModel is no longer managed by a State
  /// to prevent memory leaks and ensure clean disposal.
  void dispose() {
    _dependencyResolver = null;
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
  T readViewModel<T extends ViewModel>({
    String? key,
    Object? tag,
    ViewModelFactory<T>? factory,
  }) {
    // Create dependency configuration
    final dependencyConfig = model.ViewModelDependencyConfig<T>(
      config: model.ViewModelConfig(
        key: key,
        tag: tag,
        factory: factory,
      ),
    );
    // Check if there's a registered dependency resolver callback
    if (_dependencyResolver != null) {
      // Delegate to the registered resolver (typically from ViewModelStateMixin)
      return _dependencyResolver!<T>(dependency: dependencyConfig);
    }

    // If no dependency resolver is registered, use static read method as fallback
    return ViewModel.read<T>(
      key: key,
      tag: tag,
    );
  }

  /// Attempts to read a dependency ViewModel of type [T].
  ///
  /// Similar to [readViewModel] but returns `null` if the dependency is not found
  /// instead of throwing an exception.
  ///
  /// Parameters:
  /// - [key]: Optional key to identify the specific dependency instance
  /// - [tag]: Optional tag to identify the specific dependency instance
  /// - [factory]: Optional factory for creating the ViewModel if it doesn't exist
  ///
  /// Returns the dependency ViewModel instance if found, otherwise `null`.
  T? maybeReadViewModel<T extends ViewModel>({
    String? key,
    Object? tag,
    ViewModelFactory<T>? factory,
  }) {
    try {
      return readViewModel<T>(key: key, tag: tag, factory: factory);
    } catch (e) {
      return null;
    }
  }

  void clearDependency() {
    _dependencyResolver = null;
  }
}
