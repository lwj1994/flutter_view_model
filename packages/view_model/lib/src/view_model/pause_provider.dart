import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:view_model/src/view_model/app_lifecycle_observer.dart';

/// An abstract class that provides lifecycle pause/resume signals.
///
/// Implementers of this class can represent different sources of lifecycle
/// events, such as route changes, application state changes, or custom
/// events from a mixed-stack environment.
abstract class ViewModelPauseProvider {
  /// A stream that emits `true` when the component should be paused,
  /// and `false` when it can be resumed.
  Stream<bool> get onPauseStateChanged;

  /// Disposes the provider and releases any resources.
  void dispose();
}

/// ViewModelVisibleListener controls manual pause/resume for a page/state.
///
/// - Call [onPause] to mark the page as paused (e.g., covered by another route).
///   While paused, rebuilds triggered by bound ViewModels are ignored.
/// - Call [onResume] to mark as resumed and invoke the provided callback to
///   trigger a single refresh.
class ViewModelManualPauseProvider implements ViewModelPauseProvider {
  final _controller = StreamController<bool>.broadcast();

  /// Creates a [ViewModelManualPauseProvider] with the callback used to trigger refresh
  /// when resuming.
  ViewModelManualPauseProvider() {}

  void pause() => _controller.add(true);
  void resume() => _controller.add(false);

  @override
  void dispose() {
    _controller.close();
  }

  @override
  Stream<bool> get onPauseStateChanged => _controller.stream;
}

/// A [ViewModelPauseProvider] that signals pause/resume based on the
/// application's lifecycle state ([AppLifecycleState]).
class AppPauseLifecycleProvider implements ViewModelPauseProvider {
  final _controller = StreamController<bool>.broadcast();
  StreamSubscription<AppLifecycleState>? _subscription;

  AppPauseLifecycleProvider() {
    _subscription = AppLifecycleObserver().stream.listen((state) {
      if (state == AppLifecycleState.hidden) {
        _controller.add(true); // Should pause
      } else if (state == AppLifecycleState.resumed) {
        _controller.add(false); // Can resume
      }
    });
  }

  @override
  Stream<bool> get onPauseStateChanged => _controller.stream;

  @override
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _controller.close();
  }
}
