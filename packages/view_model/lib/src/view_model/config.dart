/// Configuration settings for the ViewModel system.
///
/// This file contains the global configuration class that controls
/// various aspects of ViewModel behavior, including logging and
/// state comparison logic.
library;

import 'package:flutter/widgets.dart';

/// Global configuration for ViewModel behavior.
///
/// This class allows customization of ViewModel system behavior including
/// logging settings and custom state equality comparison functions.
///
/// Example:
/// ```dart
/// final config = ViewModelConfig(
///   logEnable: true,
///   isSameState: (previous, current) {
///     // Custom equality logic
///     return previous?.id == current?.id;
///   },
/// );
///
/// // Apply configuration globally
/// ViewModel.config = config;
/// ```
class ViewModelConfig {
  /// Whether to enable logging for ViewModel operations.
  ///
  /// When enabled, the ViewModel system will output debug information
  /// about state changes, lifecycle events, and other operations.
  /// Defaults to `false` for production builds.
  final bool logEnable;

  /// Custom state equality comparison function for `StateViewModel`.
  ///
  /// This function is used by [StateViewModel] to determine if two states are
  /// considered equal. If this function returns `true`, the `StateViewModel`
  /// will skip the update and won't notify listeners, preventing unnecessary
  /// rebuilds.
  ///
  /// By default, if this function is not provided, the system uses `identical()`
  /// to compare the memory addresses of the two state objects.
  ///
  /// Parameters:
  /// - [previous]: The previous state value.
  /// - [current]: The new state value.
  ///
  /// Returns `true` if the states should be considered equal.
  final bool Function(dynamic previous, dynamic current)? isSameState;

  /// Creates a new ViewModel configuration.
  ///
  /// Parameters:
  /// - [logEnable]: Whether to enable debug logging (defaults to `false`)
  /// - [isSameState]: Custom state equality function (optional)
  ViewModelConfig({
    this.logEnable = false,
    this.isSameState,
  });
}
