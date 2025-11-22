## 0.8.1
- Fix: Custom `ViewModelPauseProvider` was not working properly when added late, causing pause to fail.

## 0.8.0
- **BREAKING CHANGE**: Reworked the `ViewModel` pause/resume lifecycle to a more robust and extensible provider-based architecture.
  - Default providers `PageRoutePauseProvider`, `TickModePauseProvider` and `AppPauseProvider` handle automatic pausing for route and app app lifecycle events and tickMode.
  - Added `ViewModelManualPauseProvider` for easy manual control in custom UI scenarios (e.g., `TabBarView`).
  - For details on the new API and migration, see the [Pause/Resume Lifecycle Documentation](https://github.com/lwj1994/flutter_view_model/blob/main/docs/PAUSE_RESUME_LIFECYCLE.md).

```dart
// register [ViewModel.routeObserver] to navigatorObservers.
class App {
  Widget build(context) {
    return MaterialApp(
      navigatorObservers: [ViewModel.routeObserver],
      // ... other properties
    );
  }
}


```


- Fix Devtool
- Added support for `ViewModelStatelessMixin` on `StatelessWidget`. but prefer using
  `ViewModelStateMixin` on `StatefulWidget`.

```dart
class MyWidget extends StatelessWidget with ViewModelStatelessMixin {
  const MyWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // Not recommended to get the ViewModel inside build.
    // Prefer using ViewModelStateMixin on a State. 
    final viewModel = watchViewModel<MyViewModel>(
      factory: MyViewModelFactory(),
    );
    return Text('Hello World');
  }
}
```

- Add `StateViewModelValueWatcher` to watch value changes on `StateViewModel`.

```dart
class MyWidget extends State with ViewModelStateMixin {
  const MyWidget({super.key});

  late final MyViewModel stateViewModel;

  @override
  void initState() {
    super.initState();
    stateViewModel = readViewModel<MyViewModel>(
      factory: MyViewModelFactory(),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watch value changes on `stateViewModel` and rebuild only when `name` or `age` changes.
    return StateViewModelValueWatcher<MyViewModel>(
      stateViewModel: stateViewModel,
      selectors: [(state) => state.name, (state) => state.age],
      builder: (state) {
        return Text('Name: \${state.name}, Age: \${state.age}');
      },
    );
  }
}
```

## 0.7.0

### RouteAware Auto Pause (delay rebuilds when page is paused)

- can manually control pause/resume via `viewModelVisibleListeners` exposed by
  `ViewModelStateMixin`.
  Call `viewModelVisibleListeners.onPause()` when the page is covered, and
  `viewModelVisibleListeners.onResume()`
  when it becomes visible again. Wire these methods to your own `RouteObserver` or any visibility
  mechanism.

Example:

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

---

- __BreakingChange__: Rename `ViewModelWatcher` to `ViewModelBuilder`
- Add `ViewModel#update`, we often forget calling `notifylistenr()`
  ```dart
  await update(() async {
    await repository.save(data);
     _counter++;
  });
  ```
- Add `StateViewModel#listenStateSelect` to listen value diff.

- Add `ObserverBuilder` family of widgets for fine-grained, reactive UI
  updates. [doc](https://github.com/lwj1994/flutter_view_model/blob/main/docs/value_observer_doc.md)

```dart
// shareKey for share value cross any widget
final observable = ObservableValue<int>(0, shareKey: share);
observable.value = 20;

ObserverBuilder<int>(observable: observable, 
        builder: (v) {
          return Text(v.toString());
        },
      )


// observe 2 value
ObserverBuilder2<int>(
        observable1: observable1,
        observable2: observable2,
        builder: (v1,v2) {
          //
        },
)

// observe 3 value
ObserverBuilder3<int>(
            observable1: observable1,
            observable2: observable2,
            observable3: observable3,
            builder: (v1,v2,v3) {

            },  
)
```

## 0.6.0

- Add `ViewModelBuilder` and `CachedViewModelBuilder` widgets for binding and
  listening without mixing in `ViewModelStateMixin`;
  Naming: use `shareKey` in `CachedViewModelBuilder` to avoid confusion with
  widget `Key`.

```dart
// Example: Using ViewModelBuilder without mixing ViewModelStateMixin
ViewModelBuilder<MySimpleViewModel>
(
factory: MySimpleViewModelFactory(),
builder: (vm) {
return Column(
mainAxisSize: MainAxisSize.min,
children: [
Text(vm.message),
const SizedBox(height: 8),
ElevatedButton(
onPressed: () => vm.updateMessage("Message Updated!"),
child: const Text('Update Message'),
),
],
);
},
)
```

```dart
// Example: Using CachedViewModelBuilder to bind to an existing instance
CachedViewModelBuilder<MySimpleViewModel>
(
shareKey: "shared-key", // or: tag: "shared-tag"
builder: (vm) {
return Row(
children: [
Expanded(child: Text(vm.message)),
IconButton(
onPressed: () => vm.incrementCounter(),
icon: const Icon(Icons.add),
),
],
);
},
)
```

## 0.5.0

- **Breaking Change & API Refinement**: Major overhaul of ViewModel access
  methods to clarify responsibilities and improve predictability.
    - **`watchViewModel` / `readViewModel`**:
        - Now primarily responsible for creating new ViewModel instances.
        - The `factory` parameter is now **mandatory**.
        - Behavior depends on the provided `factory`:
            - If the `factory` includes a `key`, the instance is created and
              cached (or retrieved if already cached).
            - If the `factory` has no `key`, a new, non-shared instance is created every time.
    - **New Methods for Cached Access**:
        - Introduced `watchCachedViewModel` and `readCachedViewModel` to explicitly
          find existing, cached ViewModel instances by `key` or `tag`.
        - Introduced `maybeWatchCachedViewModel` and `maybeReadCachedViewModel` for
          safely accessing cached instances without throwing errors if not found.
    - **Migration Guide**:
        - To create/watch a new instance: Continue using `watchViewModel` but you
          **must** provide a `factory`.
        - To find an existing instance: Replace `watchViewModel(key: ...)` with
          `watchCachedViewModel(key: ...)` or `readCachedViewModel(key: ...)`.
- support ViewModel-to-ViewModel Access
- Breaking change: The `key` parameter in `watchViewModel`, `readViewModel`,
  and `ViewModel.read` has been changed from `String?` to `Object?`. This
  allows for the use of custom objects as keys, but requires proper
  implementation of `==` and `hashCode` for custom key objects.

ViewModels can access other ViewModels using `readViewModel` and `watchViewModel`:

- **`readViewModel`**: Access another ViewModel without reactive connection
- **`watchViewModel`**: Create reactive dependency - automatically notifies when
  the watched ViewModel changes

When a ViewModel (the HostVM ) accesses another ViewModel (the SubVM ) via
watchViewModel , the framework automatically binds the SubVM 's lifecycle to the
HostVM 's UI observer (i.e., the State object of the StatefulWidget ).

This means both the SubVM and the HostVM are directly managed by the lifecycle of
the same State object. When this State object is disposed, if neither the SubVM
nor the HostVM has other observers, they will be disposed of together
automatically.

This mechanism ensures clear dependency relationships between ViewModels and
enables efficient, automatic resource management.

```dart
class UserProfileViewModel extends ViewModel {
  void loadData() {
    // One-time access without listening
    final authVM = watchCachedViewModel<AuthViewModel>();
    if (authVM?.isLoggedIn == true) {
      _fetchProfile(authVM!.userId);
    }
  }

  void setupReactiveAuth() {
    // Reactive access - auto-updates when auth changes
    final authVM = watchCachedViewModel<AuthViewModel>();
    // This ViewModel will be notified when authVM changes
  }


  void manualListening() {
    final authVM = watchCachedViewModel<AuthViewModel>();
    // You can also manually listen to any ViewModel
    authVM?.listen(() {
      // Custom listener logic
      _handleAuthChange(authVM);
    });
  }
}
```

## 0.4.7

- fix `ViewModel.read`

## 0.4.6

- The `view_model` package includes a powerful DevTools extension that provides
  real-time monitoring and debugging capabilities for your ViewModels during
  development.
- create `devtools_options.yaml` in root directory of project.

```yaml
description: This file stores settings for Dart & Flutter DevTools.
documentation: https://docs.flutter.dev/tools/devtools/extensions#configure-extension-enablement-states
extensions:
  - view_model: true
```

![](https://i.imgur.com/5itXPYD.png)
![](https://imgur.com/83iOQhy.png)

- Breaking change: rename `initConfig` to `initialize`

## 0.4.5

- Add `DefaultViewModelFactory` for convenient and generic ViewModel factory
  creation.

## 0.4.4

- Add `ViewModel.maybeRead`

## 0.4.3

- Add `maybeWatchViewModel` and `maybeReadViewModel`
- update `watchViewModel` find logic

```dart
VM watchViewModel<VM extends ViewModel>({
  ViewModelFactory<VM>? factory,
  Object? key,
  Object? tag,
});
```

| Parameter Name | Type                    | Optional | Description                                                                  |
|----------------|-------------------------|----------|------------------------------------------------------------------------------|
| `factory`      | `ViewModelFactory<VM>?` | ✅        | Provides the construction method for the ViewModel. Optional; if an          |
|                |                         |          | existing instance is not found in the cache, it will be used to create a new |
|                |                         |          | one.                                                                         |
| `key`          | `String?`               | ✅        | Specifies a unique key to support sharing the same ViewModel instance.       |
|                |                         |          | First, it tries to find an instance with the same key in the cache.          |
| `tag`          | `Object?`               | ✅        | Add a tag for ViewModel instance. get tag by `viewModel.tag`. and it's       |
|                |                         |          | used by find ViewModel by `watchViewModel(tag:tag)`.                         |

**🔍 Lookup Logic Priority (Important)**
The internal lookup and creation logic of `watchViewModel` is as follows
(executed in priority order):

1. If a key is passed in:

- First, attempt to find an instance with the same key in the cache.
- If a factory exists, use the factory to get a new instance.
- If no factory is found and no instance is found, an error will be thrown.

2. If a tag is passed in, attempt to find the latest created instance which has
   the same tag in the cache.
3. If nothing passed in, attempt to find the latest created instance of this
   type in the cache.

> **⚠️ If no ViewModel instance of the specified type is found, an error will be
> thrown. Ensure that the ViewModel has been correctly created and registered
> before use.**

## 0.4.2

- Support find existing ViewModel by tag

set tag in `ViewModelFactory.tag()`:

```dart
class MyViewModelFactory extends ViewModelFactory<MyViewModel> {

  @override
  Object? tag() {
    return 'tag';
  }
}
```

find existing ViewModel by tag:

```dart
late final MyViewModel viewModel;

@override
void initState() {
  super.initState();
  viewModel = watchViewModel<MyViewModel>(tag: 'tag');
}
```

## 0.4.1

_Breaking change:_

- Use `recycleViewModel` instead of `refreshViewModel`.

## 0.4.0

_Breaking change:_

- Use `ViewModel` instead of `StatelessViewModel`.
- Use `StateViewModel` instead of `ViewModel`.
- Use either `watchViewModel` or `readViewModel` instead of `getViewModel`/
  `requireExistingViewModel`.
- Use `StateViewModel.listenState` instead of `ViewModel.listen`.
- Use `ViewModel.listen` instead of `ViewModel.addListener`.

- Support `ViewModel.read<T>` to read existing view model globally.

## 0.3.0

- transfer to https://github.com/lwj1994/flutter_view_model. thank
  to [Miolin](https://github.com/Miolin)
