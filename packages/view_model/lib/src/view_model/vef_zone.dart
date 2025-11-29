// @author luwenjie on 2025/1/27 10:00:00

/// Dependency management handler for ViewModels.
///
/// This class encapsulates all dependency-related logic for ViewModels,
/// providing a clean separation of concerns and making the ViewModel class
/// more focused on its core responsibilities.
library;

import 'dart:async';

import 'package:meta/meta.dart' show internal;
import 'package:view_model/src/view_model/vef.dart';

import 'state_store.dart';

const _vefKey = #view_model_vef;

/// Runs the given [body] in a zone with the provided [vef..
/// This makes the ref available for dependency resolution.
R runWithVef<R>(R Function() body, Vef vef) {
  return runZoned(body, zoneValues: {_vefKey: vef});
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
/// ```@internal
class VefHandler {
  /// Callback function to resolve ViewModel dependencies.
  /// This is typically set by ViewModelStateMixin to delegate
  /// dependency resolution
  /// to the State that manages the ViewModel.
  @internal
  final List<Vef> dependencyVefs = [];

  VefHandler();

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
    Vef ref,
  ) {
    if (!dependencyVefs.contains(ref)) {
      dependencyVefs.add(ref);
    }
  }

  @internal
  void removeRef(
    Vef ref,
  ) {
    dependencyVefs.remove(ref);
  }

  /// Clears the dependency resolver callback and all stored dependencies.
  ///
  /// This should be called when the ViewModel is no longer managed by a State
  /// to prevent memory leaks and ensure clean disposal.
  void dispose() {
    dependencyVefs.clear();
  }

  Vef get vef {
    final r = (dependencyVefs.firstOrNull ?? (Zone.current[_vefKey] as Vef?));
    if (r == null) {
      throw ViewModelError(
        'No ref available. ViewModel must be used within a Vef context',
      );
    }
    return r;
  }
}
