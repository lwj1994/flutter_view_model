// @author luwenjie on 2025/3/25 17:24:31

/// Flutter State mixin for ViewModel integration.
///
/// This file provides the [ViewModelStateMixin] that integrates ViewModels
/// with Flutter's widget system. It handles:
/// - Automatic ViewModel lifecycle management
/// - Widget rebuilding when ViewModels change
/// - Proper disposal and cleanup
/// - Debug information for development tools
///
/// The mixin should be used with StatefulWidget's State class to enable
/// reactive ViewModel integration.
library;

import 'dart:async';
import 'package:flutter/widgets.dart';

/// A singleton observer for the application's lifecycle state.
///
/// This class listens to `AppLifecycleState` changes and broadcasts them
/// via a stream. It ensures that there's only one listener attached to
/// `WidgetsBinding.instance` for this purpose, making it efficient.
class AppLifecycleObserver with WidgetsBindingObserver {
  factory AppLifecycleObserver() => _instance;

  AppLifecycleObserver._internal() {
    WidgetsBinding.instance.addObserver(this);
  }

  static final AppLifecycleObserver _instance =
      AppLifecycleObserver._internal();

  final _streamController = StreamController<AppLifecycleState>.broadcast();

  /// A stream of `AppLifecycleState` changes.
  Stream<AppLifecycleState> get stream => _streamController.stream;

  /// The current lifecycle state of the application.
  AppLifecycleState? get currentState => WidgetsBinding.instance.lifecycleState;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _streamController.add(state);
  }

  /// Disposes the observer and closes the stream.
  ///
  /// This should typically not be called during the app's lifetime.
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _streamController.close();
  }
}
