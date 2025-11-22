// @author luwenjie on 2025/11/17 15:37:28

import 'package:flutter/foundation.dart';
import 'package:stack_trace/stack_trace.dart';

class StackPathLocator {
  // Cache path information to avoid repeated retrieval
  String? _cachedObjectPath;

  bool get ready =>
      _cachedObjectPath != null && _cachedObjectPath?.isNotEmpty == true;

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
    try {
      // Return cached result if available
      if (_cachedObjectPath != null) {
        return _cachedObjectPath!;
      }

      final frames = Trace.current().frames;

      Frame? relevantFrame;

      // Skip the frames for Trace.current() and this method itself,
      // then find the first frame that isn't from the core libraries or
      // testing frameworks.
      final candidateFrames = frames.skip(1);

      for (final f in candidateFrames) {
        final packageName = f.package;
        if (f.isCore ||
            packageName == 'flutter' ||
            packageName == 'flutter_test' ||
            packageName == 'test_api' ||
            packageName == 'stack_trace' ||
            packageName == 'view_model') {
          continue;
        }
        // The first frame that isn't a core/framework/test library is the one.
        relevantFrame = f;
        break;
      }

      if (relevantFrame != null) {
        final path = relevantFrame.uri.path;
        final line = relevantFrame.line;
        final member = relevantFrame.member ?? '';
        // The member might be 'ClassName.methodName' or just 'functionName'.
        // We'll take the part before the first dot to get the class/widget name.
        final className = member.split('.').first;
        _cachedObjectPath = '$path:$line $className';
      } else {
        // Fallback if a suitable frame cannot be found
        _cachedObjectPath = "";
      }

      return _cachedObjectPath!;
    } catch (e) {
      //
      return "";
    }
  }
}
