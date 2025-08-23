/// Configuration settings for the ViewModel system.
///
/// This file contains the global configuration class that controls
/// various aspects of ViewModel behavior, including logging and
/// state comparison logic.
library;

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

  /// Custom state equality comparison function.
  ///
  /// This function is used to determine if two states are considered equal.
  /// If this function returns `true`, the ViewModel will skip the update
  /// and won't notify listeners, preventing unnecessary rebuilds.
  ///
  /// Parameters:
  /// - [previous]: The previous state value
  /// - [state]: The new state value
  ///
  /// Returns `true` if the states should be considered equal.
  ///
  /// If not provided, the system defaults to identity comparison (`identical()`).
  final bool Function(dynamic previous, dynamic state)? isSameState;

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
