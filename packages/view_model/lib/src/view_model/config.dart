/// Configuration settings for the ViewModel system.
///
/// This file contains the global configuration class that controls
/// various aspects of ViewModel behavior, including logging and
/// state comparison logic.
library;

/// The type of error reported by [ViewModelConfig.onError].
enum ErrorType {
  /// An error thrown during listener notification
  /// (e.g., `notifyListeners()`, state listeners).
  listener,

  /// An error thrown during a lifecycle callback
  /// (e.g., `onCreate`, `onBind`, `onUnbind`).
  lifecycle,

  /// An error thrown during resource disposal
  /// (e.g., `dispose()`, `onDispose()`, cleanup).
  dispose,

  /// An error thrown during pause/resume state changes.
  pauseResume,
}

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
/// ViewModel.initialize(config: config);
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

  /// Global error handler for ViewModel errors.
  ///
  /// This callback is invoked when an error occurs during listener
  /// notification or resource disposal. By default, errors are only logged.
  /// Provide a custom handler to implement different error handling
  /// strategies (e.g., reporting to crash analytics).
  ///
  /// Parameters:
  /// - [error]: The error object that was thrown
  /// - [stackTrace]: The stack trace of the error (may be null)
  /// - [type]: The category of the error (see [ErrorType])
  ///
  /// Example:
  /// ```dart
  /// ViewModelConfig(
  ///   onError: (error, stack, type) {
  ///     FirebaseCrashlytics.instance.recordError(error, stack);
  ///   },
  /// )
  /// ```
  final void Function(Object error, StackTrace? stackTrace, ErrorType type)?
      onError;

  /// Creates a new ViewModel configuration.
  ///
  /// Parameters:
  /// - [isLoggingEnabled]: Whether to enable debug logging
  ///   (defaults to `false`)
  /// - [equals]: Custom state equality function (optional)
  /// - [onError]: Custom error handler (optional)
  ViewModelConfig({
    this.isLoggingEnabled = false,
    this.equals,
    this.onError,
  });
}
