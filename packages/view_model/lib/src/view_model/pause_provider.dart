import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:view_model/src/view_model/app_lifecycle_observer.dart';
import 'package:view_model/src/view_model/view_model.dart';

/// BinderVisibleListener controls manual pause/resume for a page/state.
///
/// - Call [onPause] to mark the page as paused (e.g., covered by another
///   route).
///   While paused, rebuilds triggered by bound ViewModels are ignored.
/// - Call [onResume] to mark as resumed and invoke the provided callback to
///   trigger a single refresh.
mixin class ViewModelBindingPauseProvider {
  final _controller = StreamController<bool>.broadcast();
  void pause() => _controller.add(true);
  void resume() => _controller.add(false);

  @mustCallSuper
  void dispose() {
    _controller.close();
  }

  Stream<bool> get onPauseStateChanged => _controller.stream;
}

/// A [ViewModelBindingPauseProvider] that signals pause/resume based on the
/// application's lifecycle state ([AppLifecycleState]).
class AppPauseProvider with ViewModelBindingPauseProvider {
  StreamSubscription<AppLifecycleState>? _subscription;

  AppPauseProvider() {
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
    super.dispose();
    _subscription?.cancel();
    _subscription = null;
    _controller.close();
  }
}

/// A [ViewModelBindingPauseProvider] that pauses/resumes based on [TickerMode].
///
/// This provider is useful for pausing ViewModels when their widget is
/// in a hidden state within a [TabBarView] or other [TickerMode] controlled
/// environments. When [TickerMode] is disabled (false), the ViewModel is
/// paused.
class TickerModePauseProvider with ViewModelBindingPauseProvider {
  ValueListenable<bool>? _notifier;
  void subscribe(ValueListenable<bool> notifier) {
    if (_notifier == notifier) return;
    _notifier?.removeListener(_onChange);
    _notifier = notifier;
    notifier.addListener(_onChange);
    _onChange();
  }

  void _onChange() {
    final v = _notifier?.value;
    if (v == null) return;
    if (v) {
      resume();
    } else {
      pause();
    }
  }

  @override
  void dispose() {
    super.dispose();
    _notifier?.removeListener(_onChange);
    _notifier = null;
  }
}

/// A [ViewModelBindingPauseProvider] that uses [RouteAware] to determine pause state
/// based on route navigation events (push, pop).
class PageRoutePauseProvider with ViewModelBindingPauseProvider, RouteAware {
  final List<PageRoute> _subscribedRoutes = [];
  final RouteObserver<PageRoute> _observer = ViewModel.routeObserver;

  /// Creates a [PageRoutePauseProvider] with the given binder name.
  PageRoutePauseProvider();

  /// Subscribes the provider to a specific route.
  ///
  /// This method ensures that the provider is only subscribed once
  /// to each route,
  /// preventing duplicate subscriptions.
  void subscribe(PageRoute route) {
    if (_subscribedRoutes.contains(route)) return;
    unsubscribe(_observer);
    _subscribedRoutes.add(route);
    _observer.subscribe(this, route);
  }

  /// Unsubscribes the provider from all routes.
  void unsubscribe(RouteObserver<PageRoute> observer) {
    if (_subscribedRoutes.isEmpty) return;
    observer.unsubscribe(this);
    _subscribedRoutes.clear();
  }

  @override
  Stream<bool> get onPauseStateChanged => _controller.stream;

  @override
  void dispose() {
    super.dispose();
    unsubscribe(_observer);
  }

  @override
  void didPush() {
    // The route was pushed, but it's visible, so no state change.
  }

  @override
  void didPop() {
    // The current route has been popped off the navigator.
    // It is no longer visible, so it should be considered paused.
    pause();
  }

  @override
  void didPushNext() {
    // A new route has been pushed on top of the current one.
    // The current route is now obscured and should be paused.
    pause();
  }

  @override
  void didPopNext() {
    // The route that was on top has been popped.
    // The current route is now visible again and should be resumed.
    resume();
  }
}
