/// Logging utilities for the ViewModel system.
///
/// This file provides centralized logging functionality for the ViewModel
/// framework. It respects the global logging configuration and provides
/// consistent log formatting across all ViewModel components.
///
/// @author luwenjie on 2025/3/27 11:55:17
library;

import 'package:flutter/foundation.dart';
import 'package:view_model/view_model.dart';

/// Logs a message from the ViewModel system.
///
/// This function provides centralized logging for all ViewModel-related
/// operations. It respects the global logging configuration set in
/// [ViewModel.config.isLoggingEnabled] and only outputs messages when logging
/// is enabled.
///
/// The function uses Flutter's [debugPrint] to ensure proper output
/// handling in both debug and release modes. All messages are prefixed
/// with "view_model:" for easy identification in logs.
///
/// Parameters:
/// - [s]: The message to log
///
/// Example:
/// ```dart
/// // Enable logging in configuration
/// ViewModel.initialize(config: ViewModelConfig(isLoggingEnabled: true));
///
/// // Log messages will now appear
/// viewModelLog('ViewModel created: MyViewModel');
/// viewModelLog('State updated: ${newState}');
/// ```
void viewModelLog(String s) {
  if (!ViewModel.config.isLoggingEnabled) return;
  debugPrint("view_model:  $s");
}

/// Reports an error from the ViewModel system through the unified error
/// handling pipeline.
///
/// If [ViewModelConfig.onError] is configured, the error is forwarded to it.
/// If the callback itself throws, the original error is logged as a fallback.
/// When no callback is configured, the error is always logged regardless of
/// [ViewModelConfig.isLoggingEnabled] — errors must never be silently
/// swallowed.
void reportViewModelError(
  Object error,
  StackTrace? stack,
  ErrorType type,
  String fallbackMessage,
) {
  final handler = ViewModel.config.onError;
  if (handler != null) {
    try {
      handler(error, stack, type);
    } catch (handlerError) {
      debugPrint(
        'view_model ERROR: onError callback threw ($handlerError). '
        'Original: $fallbackMessage: $error\n${stack ?? ""}',
      );
    }
  } else {
    debugPrint('view_model ERROR: $fallbackMessage: $error\n${stack ?? ""}');
  }
}
