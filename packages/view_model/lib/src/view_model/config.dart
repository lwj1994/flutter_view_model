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
///   isLoggingEnabled: true,
///   equals: (previous, current) {
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
  final bool isLoggingEnabled;

  /// A global custom equality comparison function.
  ///
  /// This function is used to determine if two values are considered equal,
  /// and it is utilized in two main places:
  /// 1. By `StateViewModel` to compare the previous and new states.
  /// 2. By the `listen` method's selector to compare the previous and new
  ///    selected values.
  ///
  /// If this function returns `true`, the update is skipped, preventing
  /// unnecessary notifications and rebuilds.
  ///
  /// If not provided, `StateViewModel` defaults to `identical()`, while the
  /// `listen` selector defaults to the `==` operator.
  ///
  /// Parameters:
  /// - [previous]: The previous value.
  /// - [current]: The new value.
  ///
  /// Returns `true` if the values should be considered equal.
  final bool Function(dynamic previous, dynamic current)? equals;

  /// Creates a new ViewModel configuration.
  ///
  /// Parameters:
  /// - [isLoggingEnabled]: Whether to enable debug logging (defaults to `false`)
  /// - [equals]: Custom state equality function (optional)
  ViewModelConfig({
    this.isLoggingEnabled = false,
    this.equals,
  });
}
