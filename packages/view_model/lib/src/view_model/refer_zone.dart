// @author luwenjie on 2025/1/27 10:00:00

/// Dependency management handler for ViewModels.
///
/// This class encapsulates all dependency-related logic for ViewModels,
/// providing a clean separation of concerns and making the ViewModel class
/// more focused on its core responsibilities.
library;

import 'dart:async';

import 'package:meta/meta.dart' show internal;
import 'package:view_model/src/view_model/refer.dart';

import 'state_store.dart';

const _referKey = #view_model_refer;

/// Runs the given [body] in a zone with the provided [refer].
/// This makes the ref available for dependency resolution.
R runWithRefer<R>(R Function() body, Refer refer) {
  return runZoned(body, zoneValues: {_referKey: refer});
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
class RefHandler {
  /// Callback function to resolve ViewModel dependencies.
  /// This is typically set by ViewModelStateMixin to delegate
  /// dependency resolution
  /// to the State that manages the ViewModel.
  @internal
  final List<Refer> dependencyRefs = [];

  RefHandler();

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
    Refer ref,
  ) {
    if (!dependencyRefs.contains(ref)) {
      dependencyRefs.add(ref);
    }
  }

  @internal
  void removeRef(
    Refer ref,
  ) {
    dependencyRefs.remove(ref);
  }

  /// Clears the dependency resolver callback and all stored dependencies.
  ///
  /// This should be called when the ViewModel is no longer managed by a State
  /// to prevent memory leaks and ensure clean disposal.
  void dispose() {
    dependencyRefs.clear();
  }

  Refer get refer {
    final r =
        (dependencyRefs.firstOrNull ?? (Zone.current[_referKey] as Refer?));
    if (r == null) {
      throw ViewModelError(
        'No ref available. ViewModel must be used within a Refer context',
      );
    }
    return r;
  }
}
