# Refer Pause/Resume Lifecycle

This is particularly useful for:
- **Pausing UI Updates**: When a Refer is paused (e.g., widget navigated away from), it stops responding to ViewModel state changes, preventing unnecessary rebuilds. The ViewModel continues to emit notifications, but the paused Refer ignores them.
- **Resuming UI Updates**: When the Refer resumes (e.g., widget navigated back to), it automatically checks for missed updates and rebuilds if necessary.


## How It Works

The pause/resume mechanism is managed by a `PauseAwareController`, which orchestrates multiple `ReferPauseProvider`s to determine the widget's visibility.

> [!IMPORTANT]
> **Pause Logic Rule**:
> The Refer is considered **PAUSED** if **ANY** of its providers signal a pause state.
> The Refer is considered **RESUMED** only when **ALL** providers signal a resume (not paused) state.
>


The core components are:
1.  **`PauseAwareController`**: The brain of the operation. It subscribes to all providers and calls the `Refer`'s `onPause()` or `onResume()` methods based on their combined state.
2.  **`ReferPauseProvider`**: A source of pause/resume events. The package includes default providers for common scenarios, but you can create your own for custom logic.

By default, `ViewModelStateMixin` (for `StatefulWidget`) automatically sets up a `PauseAwareController` with three standard providers:
-   **`PageRoutePauseProvider`**: Uses `RouteAware` to pause the `Refer` when a new route is pushed on top of its widget or when the widget's route is popped.
-   **`AppPauseLifecycleProvider`**: Uses `WidgetsBindingObserver` to pause the `Refer` when the entire application is sent to the background.
-   **`TickerModePauseProvider`**: Automatically pauses the `Refer` when the widget is in a hidden state within a `TabBarView` or `PageView` (controlled by `TickerMode`).

`ViewModelStatelessMixin` (for `StatelessWidget`) only includes the **`AppPauseLifecycleProvider`** by default.

## Automatic Pause/Resume

For the automatic pause/resume mechanism to work with navigation, you must add `ViewModel.routeObserver` to your `MaterialApp`'s `navigatorObservers`:

```dart
MaterialApp(
  navigatorObservers: [ViewModel.routeObserver],
  // ... other properties
)
```

With this setup, any `Refer` associated with a widget (e.g., a full-screen page) will automatically pause when the widget is no longer visible and resume when it comes back into view. During pause, the Refer stops responding to ViewModel updates. This covers:
1.  **Navigation changes**: Pushing/popping routes.
2.  **App lifecycle changes**: App going into the background.
3.  **Tab switching**: Switching tabs in a `TabBarView` or pages in a `PageView` (handled automatically by `TickerModePauseProvider`).

## Customizing the Lifecycle (Advanced)

The default providers cover the most common cases, but you can also create your own `ReferPauseProvider` and add it to your `Refer` to handle custom visibility logic.

### Example: Manual Control

Let's say you have a specific requirement to pause a Refer manually. You can use `ManualReferPauseProvider`.

```dart
class _MyPageState extends State<MyPage> with ViewModelStateMixin<MyPage> {
  final _manualPauseProvider = ManualReferPauseProvider();

  @override
  void initState() {
    super.initState();
    // Register your custom provider to the Refer
    binder.addPauseProvider(_manualPauseProvider);
  }

  void togglePause() {
    if (shouldPause) {
        _manualPauseProvider.pause();
    } else {
        _manualPauseProvider.resume();
    }
  }

  @override
  void dispose(){
    super.dispose();
    _manualPauseProvider.dispose();
  }
}
```