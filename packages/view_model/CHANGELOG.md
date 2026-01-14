## 0.14.0-dev.0
- Simplify Architecture Guide structure in `ARCHITECTURE_GUIDE.md` and `ARCHITECTURE_GUIDE_ZH.md`
- Update `ViewModelStateMixin` docs
- Fix bugs

## 0.13.0
- Support `aliveForever`
- Fix: resolve unbindVef race condition
- Update lints

## 0.12.0 
- update docs

## 0.11.0

- Add: test-time proxy overrides for providers
  - `ViewModelProviderWithArg/Arg2/Arg3/Arg4` now support `setProxy` and
    `clearProxy` to override `builder`, `key`, `tag`, `isSingleton` during tests.
  - Mirrors existing no-arg `ViewModelProvider` proxy behavior for consistency.

## 0.10.0
- Feat: Introduce methods to retrieve and watch multiple ViewModel instances by tag (`readCachesByTag`, `watchCachesByTag`)

## 0.9.2
- add more tests

## 0.9.1
- update dependencies

## 0.9.0
🎉 **Major Update: Introducing ViewModelProvider & Code Generator**

🚀 ViewModelProvider: Simpler, Cleaner, Better
**Replaces the verbose Factory pattern** with a declarative, type-safe provider system.

**Before (Factory pattern):**
```dart
class CounterViewModelFactory extends ViewModelFactory<CounterViewModel> {
  @override
  CounterViewModel build() => CounterViewModel();
}

final vm = watchViewModel(factory: CounterViewModelFactory());
```

**After (Provider pattern):**
```dart
/// auto generated provider for CounterViewModel
final counterProvider = ViewModelProvider<CounterViewModel>(
  builder: () => CounterViewModel(),
);

final vm = vef.watch(counterProvider);
```

**With Arguments:**
```dart
/// auto generated provider for UserViewModel
final userProvider = ViewModelProvider.arg<UserViewModel, String>(
  builder: (userId) => UserViewModel(userId),
  key: (userId) => 'user-$userId',
);

final vm = vef.watch(userProvider('user-123'));
```

[Migration Guide](https://github.com/lwj1994/flutter_view_model/blob/main/packages/view_model/docs/VIEWMODEL_PROVIDER_MIGRATION.md)

---

### 🤖 Code Generator: Zero Boilerplate

Introducing **`view_model_generator`** - automatically generate `ViewModelProvider` definitions from annotations.

**Installation:**
```yaml
dependencies:
  view_model: ^latest
dev_dependencies:
  build_runner: ^latest
  view_model_generator: ^latest
```

**Usage:**
```dart
import 'package:view_model_generator/view_model_generator.dart';

part 'counter_view_model.vm.dart';

@genProvider
class CounterViewModel extends ViewModel {
  int count = 0;
  void increment() => update(() => count++);
}
```

**Run generator:**
```bash
dart run build_runner build
```

**Generated code:**
```dart
// counter_view_model.vm.dart
final counterProvider = ViewModelProvider<CounterViewModel>(
  builder: () => CounterViewModel(),
);
```

The generator supports ViewModels with up to 4 constructor parameters and automatically generates the appropriate `ViewModelProvider.argX` variant.

Package: https://pub.dev/packages/view_model_generator

---

### 🔄 New Unified API: `vef.watch` & `vef.read`

**Everything is Vef** - A unified, consistent API for accessing ViewModels.

**New Recommended API:**
```dart
// Watch (reactive)
final vm = vef.watch(counterProvider);

// Read (non-reactive)
final vm = vef.read(counterProvider);

// Watch cached by key/tag
final vm = vef.watchCached<UserViewModel>(key: 'user-123');
final vm = vef.readCached<UserViewModel>(tag: 'current-user');
```

**Legacy API (still supported):**
```dart
// Old API still works for backward compatibility
final vm = vef.watchViewModel(factory: CounterViewModelFactory());
final vm = vef.readViewModel(factory: CounterViewModelFactory());
```

> **Note**: While `watchViewModel` and `readViewModel` are still supported, we recommend migrating to the new `vef.watch` and `vef.read` API with `ViewModelProvider` for better type safety and less boilerplate.

---

### 🌟 Everything is Vef

`Vef` is the core abstraction of the `view_model` library, responsible for managing ViewModel lifecycle and dependency injection. `WidgetMixin` is essentially just a wrapper around `WidgetVef`.

This means you can use ViewModel in **any Dart class**, independent of Widgets.

**Custom Vef Example:**
```dart
class StartTaskVef with Vef {
  Future<void> runStartupTasks() async {
    final authVM = vef.watch(authProvider);
    await authVM.checkLoginStatus();
    
    final configVM = vef.watch(configProvider);
    await configVM.loadRemoteConfig();
  }
  
  @override
  void dispose() {
    super.dispose();
    // Clean up all watched ViewModels
  }
}
```

Use cases:
- **Pure Dart Tests**: Test ViewModel interactions without `testWidgets`
- **Startup Tasks**: Execute initialization logic before any Widget is rendered

See [Custom Vef Documentation](https://github.com/lwj1994/flutter_view_model/blob/main/packages/view_model/README.md#custom-vef) for details.

---

### 🔧 Other Changes

- Renamed `ViewModelPauseProvider` to `VefPauseProvider` for consistency
- Improved type inference for `ViewModelProvider.argX` variants


## 0.8.4
- Update docs about design philosophy

## Everything is ViewModel

We redefine the "ViewModel" not as a specific MVVM component, but as a **Specialized Manager Container** equipped with lifecycle awareness.

**1. Widget-Centric Architecture**
In a Flutter App, every action revolves around Pages and Widgets. No matter how complex the logic is, the ultimate consumer is always a Widget. Therefore, binding the Manager's lifecycle directly to the Widget tree is the most logical and natural approach.

**2. One Concept, Flexible Scopes**
You don't need to distinguish between "Services", "Controllers", or "Stores". It's all just a ViewModel. The difference is only **where** you attach it:
*   **Global:** Attach to the top-level **`AppMain`**. It lives as long as the App (Singleton).
*   **Local:** Attach to a **Page**. It follows the page's lifecycle automatically.
*   **Shared:** Use a unique **`key`** (e.g., ProductID) to share the exact same instance across different Widgets.

**3. Seamless Composition & Decoupling**
ViewModels can directly depend on and read other ViewModels internally (e.g., a `UserVM` reading a `NetworkVM`). However, the ViewModel itself remains **Widget-Agnostic**—it holds state and logic but does not know about the Widget's existence or hold a `BuildContext`.

**4. Out-of-the-Box Simplicity**
Compared to **GetIt** (which requires manual binding glue code) or **Riverpod** (which involves complex graph concepts), this approach is strictly pragmatic. It provides automated lifecycle management and dependency injection immediately, with zero boilerplate.



## 0.8.3
- Fix docs

## 0.8.2
- Update docs


## 0.8.1
- Fix: Custom `VefPauseProvider` was not working properly when added late, causing pause to fail.

## 0.8.0
- **BREAKING CHANGE**: Reworked the `Vef` pause/resume lifecycle to a more robust and extensible provider-based architecture.
  - Default providers `PageRoutePauseProvider`, `TickerModePauseProvider` and `AppPauseProvider` handle automatic pausing for route and app app lifecycle events and tickMode.
  - Added `ManualVefPauseProvider` for easy manual control in custom UI scenarios (e.g., `TabBarView`).
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
  late final viewModel = watchViewModel<MyViewModel>(
      factory: MyViewModelFactory(),
    );
  const MyWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Text('Hello World ${viewModel}');
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

- Add `ViewModelProvider` for convenient and generic ViewModel factory
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
