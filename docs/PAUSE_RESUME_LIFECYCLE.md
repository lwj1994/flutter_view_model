# ViewModel Pause/Resume Lifecycle

This is particularly useful for:
- **Pausing UI Updates**: When a widget is paused (e.g., navigated away from), it stops responding to ViewModel state changes, preventing unnecessary rebuilds.
- **Resuming UI Updates**: When the widget resumes (e.g., navigated back to), it automatically checks for missed updates and rebuilds if necessary.


## How It Works

The pause/resume mechanism is managed by a `PauseAwareController`, which orchestrates multiple `ViewModelPauseProvider`s to determine the widget's visibility.

> [!IMPORTANT]
> **Pause Logic Rule**:
> The ViewModel is considered **PAUSED** if **ANY** of its providers signal a pause state.
> The ViewModel is considered **RESUMED** only when **ALL** providers signal a resume (not paused) state.
>


The core components are:
1.  **`PauseAwareController`**: The brain of the operation. It subscribes to all providers and calls the `ViewModel`'s `onPause()` or `onResume()` methods based on their combined state.
2.  **`ViewModelPauseProvider`**: A source of pause/resume events. The package includes default providers for common scenarios, but you can create your own for custom logic.

By default, `ViewModelStateMixin` (for `StatefulWidget`) automatically sets up a `PauseAwareController` with three standard providers:
-   **`PageRoutePauseProvider`**: Uses `RouteAware` to pause the `ViewModel` when a new route is pushed on top of its widget or when the widget's route is popped.
-   **`AppPauseLifecycleProvider`**: Uses `WidgetsBindingObserver` to pause the `ViewModel` when the entire application is sent to the background.
-   **`TickerModePauseProvider`**: Automatically pauses the `ViewModel` when the widget is in a hidden state within a `TabBarView` or `PageView` (controlled by `TickerMode`).

`ViewModelStatelessMixin` (for `StatelessWidget`) only includes the **`AppPauseLifecycleProvider`** by default.

## Automatic Pause/Resume

For the automatic pause/resume mechanism to work with navigation, you must add `ViewModel.routeObserver` to your `MaterialApp`'s `navigatorObservers`:

```dart
MaterialApp(
  navigatorObservers: [ViewModel.routeObserver],
  // ... other properties
)
```

With this setup, any `ViewModel` associated with a route (e.g., a full-screen page) will automatically pause when it's no longer visible and resume when it comes back into view. This covers:
1.  **Navigation changes**: Pushing/popping routes.
2.  **App lifecycle changes**: App going into the background.
3.  **Tab switching**: Switching tabs in a `TabBarView` or pages in a `PageView` (handled automatically by `TickerModePauseProvider`).

## Customizing the Lifecycle (Advanced)

The default providers cover the most common cases, but you can also create your own `ViewModelPauseProvider` and pass it to your `ViewModel` to handle custom visibility logic.

### Example: Manual Control

Let's say you have a specific requirement to pause a ViewModel manually. You can use `ViewModelManualPauseProvider`.

```dart
class _MyPageState extends State<MyPage> with ViewModelStateMixin<MyPage> {
  final _manualPauseProvider = ViewModelManualPauseProvider();

  @override
  void initState() {
    super.initState();
    // Register your custom provider
    addViewModelPauseProvider(_manualPauseProvider);
  }

  void togglePause() {
    if (shouldPause) {
        _manualPauseProvider.pause();
    } else {
        _manualPauseProvider.resume();
    }
  }

  void dispose(){
    super.dispose()
    _manualPauseProvider.dispose();
  }
}
```