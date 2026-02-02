// @author luwenjie on 2025/1/27 10:00:00

/// Dependency management handler for ViewModels.
///
/// This class encapsulates all dependency-related logic for ViewModels,
/// providing a clean separation of concerns and making the ViewModel class
/// more focused on its core responsibilities.
library;

import 'dart:async';

import 'package:meta/meta.dart' show internal;
import 'package:view_model/src/view_model/view_model_binding.dart';

import 'state_store.dart';

const _bindingKey = #view_model_binding;

/// Runs the given [body] in a zone with the provided [binding].
/// This makes the binding available for dependency resolution.
R runWithBinding<R>(R Function() body, ViewModelBinding binding) {
  return runZoned(body, zoneValues: {_bindingKey: binding});
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
class ViewModelBindingHandler {
  /// Callback function to resolve ViewModel dependencies.
  /// This is typically set by ViewModelStateMixin to delegate
  /// dependency resolution
  /// to the State that manages the ViewModel.
  @internal
  final List<ViewModelBinding> dependencyBindings = [];

  ViewModelBindingHandler();

  /// Sets the dependency resolver callback.
  ///
  /// This should only be called by ViewModelStateMixin or similar
  /// framework code.
  /// The resolver is responsible for creating or retrieving
  /// ViewModel instances.
  ///
  /// Parameters:
  /// - [resolver]: Function that resolves dependencies with listen parameter
  @internal
  void addRef(
    ViewModelBinding ref,
  ) {
    if (!dependencyBindings.contains(ref)) {
      dependencyBindings.add(ref);
    }
  }

  @internal
  void removeRef(
    ViewModelBinding ref,
  ) {
    dependencyBindings.remove(ref);
  }

  /// Clears the dependency resolver callback and all stored dependencies.
  ///
  /// This should be called when the ViewModel is no longer managed by a State
  /// to prevent memory leaks and ensure clean disposal.
  void dispose() {
    dependencyBindings.clear();
  }

  ViewModelBinding get binding {
    final r = (dependencyBindings.firstOrNull ??
        (Zone.current[_bindingKey] as ViewModelBinding?));
    if (r == null) {
      throw ViewModelError(
        'No binding available. ViewModel must be used within a ViewModelBinding context',
      );
    }
    return r;
  }
  

}
