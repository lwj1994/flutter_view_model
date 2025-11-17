# ViewModel Pause/Resume Lifecycle

The `flutter_view_model` package provides a powerful lifecycle mechanism for `ViewModel`s tied to widget visibility. This is primarily handled by `ViewModelStateMixin`. When a widget is not visible, its associated `ViewModel` can be "paused". In this state, notifications from the `ViewModel` that would normally trigger UI updates are suppressed. When the widget becomes visible again, the `ViewModel` is "resumed", and the mixin triggers a single `setState()` to ensure the UI reflects the latest `ViewModel` state.

This is particularly useful for:
- Stopping background tasks (like animations, timers, or data polling) when the user navigates away from a screen, thus saving CPU and battery.
- Refreshing data when the user returns to a screen.
- Preventing unnecessary UI updates for widgets that are not on screen by batching them into a single update on resume.


## How It Works

The pause/resume mechanism is built upon two main components:
1.  **Automatic Handling via `RouteAware`**: For `StatefulWidget`s that are direct routes (i.e., pages pushed onto the `Navigator`), `ViewModelStateMixin` automatically listens to route changes.
2.  **Manual Control**: For widgets whose visibility is not tied to navigation routes (e.g., tabs in a `TabBarView`), the mixin exposes listeners for manual control.

### 1. Automatic Pause/Resume (Route-Aware)
To make this work, you must add `ViewModel.routeObserver` to your `MaterialApp`:

```dart
MaterialApp(
  navigatorObservers: [ViewModel.routeObserver],
  // ... other properties
)
```

### 2. Manual Pause/Resume
The automatic mechanism only works for route-based navigation. What about widgets inside a `TabBarView`, a `PageView`, or a custom container that manages visibility?

For these cases, `ViewModelStateMixin` exposes `viewModelVisibleListeners`. You can manually trigger the pause and resume events.


```dart
class _MyPageState extends State<MyPage> with ViewModelStateMixin<MyPage>, RouteAware {
  void didPushNext() {
    viewModelVisibleListeners.onPause();
  }

  void didPopNext() {
    viewModelVisibleListeners.onResume(); // triggers one refresh
  }
}
```