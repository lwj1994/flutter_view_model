// @author luwenjie on 2025/11/17 15:37:28

import 'package:flutter/foundation.dart';
import 'package:stack_trace/stack_trace.dart';

class StackPathLocator {
  // Cache path information to avoid repeated retrieval
  String? _cachedObjectPath;

  /// Gets the file path and line number where this mixin is being used.
  ///
  /// This method analyzes the current call stack to determine the exact
  /// location where ViewModelStateMixin is being used. It handles both
  /// regular file paths and package: format paths.
  ///
  /// The result is cached to avoid repeated stack trace analysis.
  ///
  /// Returns:
  /// - In debug mode: A string like "lib/pages/counter_page.dart:25"
  /// - In release mode: An empty string
  /// - If path cannot be determined: The runtime type as fallback
  ///
  /// Example output: `lib/pages/counter_page.dart:25`
  String getCurrentObjectPath() {
    if (!kDebugMode) return "";

    // Return cached result if available
    if (_cachedObjectPath != null) {
      return _cachedObjectPath!;
    }

    final frames = Trace.current().frames;

    // Find the first 3 unique frames that are not part of the view_model
    // package, the Flutter framework, or the Dart core libraries.
    final externalLocations = frames
        .where((f) =>
            f.package != null &&
            f.package != 'view_model' &&
            f.package != 'flutter' &&
            !f.isCore &&
            f.line != null) // Ensure line number is available
        .map((f) => '${f.uri.path}:${f.line}') // Format to path:line
        .toSet() // Remove duplicates
        .take(10) // Take the first unique locations
        .toList();

    if (externalLocations.isNotEmpty) {
      _cachedObjectPath = externalLocations.join('\n') + '\n';
    } else {
      // Fallback to runtimeType if path cannot be retrieved
      _cachedObjectPath = "$runtimeType\n";
    }

    return _cachedObjectPath!;
  }
}
