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
/// [ViewModel.config.logEnable] and only outputs messages when logging
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
/// ViewModel.config = ViewModelConfig(logEnable: true);
///
/// // Log messages will now appear
/// viewModelLog('ViewModel created: MyViewModel');
/// viewModelLog('State updated: ${newState}');
///
/// // Disable logging
/// ViewModel.config = ViewModelConfig(logEnable: false);
///
/// // This message will not appear
/// viewModelLog('This will not be logged');
/// ```
void viewModelLog(String s) {
  if (!ViewModel.config.logEnable) return;
  debugPrint("view_model:  $s");
}
