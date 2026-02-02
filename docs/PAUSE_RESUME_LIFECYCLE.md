# ViewModelBinding Pause/Resume Lifecycle

This is particularly useful for:
- **Pausing UI Updates**: When a ViewModelBinding is paused (e.g., widget navigated away from), it stops responding to ViewModel state changes, preventing unnecessary rebuilds. The ViewModel continues to emit notifications, but the paused binding ignores them.
- **Resuming UI Updates**: When the ViewModelBinding resumes (e.g., widget navigated back to), it automatically checks for missed updates and rebuilds if necessary.


## How It Works

The pause/resume mechanism is managed by a `PauseAwareController`, which orchestrates multiple `ViewModelBindingPauseProvider`s to determine the widget's visibility.

> [!IMPORTANT]
> **Pause Logic Rule**:
> The ViewModelBinding is considered **PAUSED** if **ANY** of its providers signal a pause state.
> The ViewModelBinding is considered **RESUMED** only when **ALL** providers signal a resume (not paused) state.
>


The core components are:
1.  **`PauseAwareController`**: The brain of the operation. It subscribes to all providers and calls the `ViewModelBinding`'s `onPause()` or `onResume()` methods based on their combined state.
2.  **`ViewModelBindingPauseProvider`**: A source of pause/resume events. The package includes default providers for common scenarios, but you can create your own for custom logic.

By default, `ViewModelStateMixin` (for `StatefulWidget`) automatically sets up a `PauseAwareController` with three standard providers:
-   **`PageRoutePauseProvider`**: Uses `RouteAware` to pause the binding when a new route is pushed on top of its widget or when the widget's route is popped.
-   **`AppPauseProvider`**: Uses `WidgetsBindingObserver` to pause the binding when the entire application is sent to the background.
-   **`TickerModePauseProvider`**: Automatically pauses the binding when the widget is in a hidden state within a `TabBarView` or `PageView` (controlled by `TickerMode`).

`ViewModelStatelessMixin` (for `StatelessWidget`) only includes the **`AppPauseProvider`** by default.

## Automatic Pause/Resume

For the automatic pause/resume mechanism to work with navigation, you must add `ViewModel.routeObserver` to your `MaterialApp`'s `navigatorObservers`:

```dart
MaterialApp(
  navigatorObservers: [ViewModel.routeObserver],
  // ... other properties
)
```

With this setup, any ViewModelBinding associated with a widget (e.g., a full-screen page) will automatically pause when the widget is no longer visible and resume when it comes back into view. During pause, the binding stops responding to ViewModel updates. This covers:
1.  **Navigation changes**: Pushing/popping routes.
2.  **App lifecycle changes**: App going into the background.
3.  **Tab switching**: Switching tabs in a `TabBarView` or pages in a `PageView` (handled automatically by `TickerModePauseProvider`).

## Customizing the Lifecycle (Advanced)

The default providers cover the most common cases, but you can also create your own `ViewModelBindingPauseProvider` and add it to your binding to handle custom visibility logic.

### Example: Manual Control

Let's say you have a specific requirement to pause a binding manually. You can create a custom `ViewModelBindingPauseProvider`.

```dart
class _MyPageState extends State<MyPage> with ViewModelStateMixin<MyPage> {
  final _manualPauseProvider = _ManualPauseProvider();

  @override
  void initState() {
    super.initState();
    // Register your custom provider to the binding
    viewModelBinding.addPauseProvider(_manualPauseProvider);
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

class _ManualPauseProvider with ViewModelBindingPauseProvider {}
```
