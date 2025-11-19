# ViewModel Pause/Resume Lifecycle

The `view_model` package provides a powerful lifecycle mechanism for `ViewModel`s tied to widget visibility. This is primarily handled by `ViewModelStateMixin`. When a widget is not visible, its associated `ViewModel` can be "paused". In this state, notifications from the `ViewModel` that would normally trigger UI updates are suppressed. When the widget becomes visible again, the `ViewModel` is "resumed", and the mixin triggers a single `setState()` to ensure the UI reflects the latest `ViewModel` state.

This is particularly useful for:
- Stopping background tasks (like animations, timers, or data polling) when the user navigates away from a screen, thus saving CPU and battery.
- Refreshing data when the user returns to a screen.
- Preventing unnecessary UI updates for widgets that are not on screen by batching them into a single update on resume.


## How It Works

The pause/resume mechanism is managed by a `PauseAwareController`, which orchestrates multiple `ViewModelPauseProvider`s to determine the widget's visibility. A `ViewModel` is paused if *any* of its providers signal a pause state.

The core components are:
1.  **`PauseAwareController`**: The brain of the operation. It subscribes to all providers and calls the `ViewModel`'s `onPause()` or `onResume()` methods based on their combined state.
2.  **`ViewModelPauseProvider`**: A source of pause/resume events. The package includes default providers for common scenarios, but you can create your own for custom logic.

By default, `ViewModelWidget` and `ViewModelStateMixin` automatically set up a `PauseAwareController` with two standard providers:
-   **`PageRoutePauseProvider`**: Uses `RouteAware` to pause the `ViewModel` when a new route is pushed on top of its widget or when the widget's route is popped.
-   **`AppPauseLifecycleProvider`**: Uses `WidgetsBindingObserver` to pause the `ViewModel` when the entire application is sent to the background.

## Automatic Pause/Resume

For the automatic pause/resume mechanism to work with navigation, you must add `ViewModel.routeObserver` to your `MaterialApp`'s `navigatorObservers`:

```dart
MaterialApp(
  navigatorObservers: [ViewModel.routeObserver],
  // ... other properties
)
```

With this setup, any `ViewModel` associated with a route (e.g., a full-screen page) will automatically pause when it's no longer visible and resume when it comes back into view. This covers both navigation changes (pushing/popping routes) and app lifecycle changes (app going into the background).

## Customizing the Lifecycle (Advanced)

The default providers cover the most common cases, but what about widgets whose visibility isn't tied to routes, such as tabs in a `TabBarView` or pages in a `PageView`?

The new architecture is designed for this. You can create your own `ViewModelPauseProvider` and pass it to your `ViewModel` to handle custom visibility logic.

### Example: Handling a TabBarView

Let's say you have a `ViewModel` inside a tab that should only be active when its tab is visible. For this, you can use the `ViewModelManualPauseProvider` that comes with the package.

**Use `ViewModelManualPauseProvider` in your widget:**

In your `StatefulWidget`, create an instance of `ViewModelManualPauseProvider` and control it based on the `TabController`'s state. Then, pass this provider to your `ViewModel`.

```dart
class _MyTabbedPageState extends State<MyTabbedPage>
    with SingleTickerProviderStateMixin, ViewModelStateMixin<MyViewModel> {
  late final TabController _tabController;
  final _manualPauseProvider = ViewModelManualPauseProvider();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      // Pause if the tab is not the first one (index 0).
      _manualPauseProvider.setPaused(_tabController.index != 0);
    });
    addViewModelPauseProvider(_manualPauseProvider);
  }

  @override
  Widget build(BuildContext context) {
   
    return YourWidget();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
```

This approach provides a clean and reusable way to integrate any custom visibility logic into the `ViewModel`'s lifecycle.