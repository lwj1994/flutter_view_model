
## 0.5.0

* **Breaking Change & API Refinement**: Major overhaul of ViewModel access
  methods to clarify responsibilities and improve predictability.
  - **`watchViewModel` / `readViewModel`**\:
    - Now primarily responsible for creating new ViewModel instances.
    - The `factory` parameter is now **mandatory**.
    - Behavior depends on the provided `factory`:
      - If the `factory` includes a `key`, the instance is created and
        cached (or retrieved if already cached).
      - If the `factory` has no `key`, a new, non-shared instance is created every time.
  - **New Methods for Cached Access**\:
    - Introduced `watchCachedViewModel` and `readCachedViewModel` to explicitly
      find existing, cached ViewModel instances by `key` or `tag`.
    - Introduced `maybeWatchCachedViewModel` and `maybeReadCachedViewModel` for
      safely accessing cached instances without throwing errors if not found.
  - **Migration Guide**\:
    - To create/watch a new instance: Continue using `watchViewModel` but you
      **must** provide a `factory`.
    - To find an existing instance: Replace `watchViewModel(key: ...)` with
      `watchCachedViewModel(key: ...)` or `readCachedViewModel(key: ...)`.
* support ViewModel-to-ViewModel Access
* Breaking change: The `key` parameter in `watchViewModel`, `readViewModel`,
  and `ViewModel.read` has been changed from `String?` to `Object?`. This
  allows for the use of custom objects as keys, but requires proper
  implementation of `==` and `hashCode` for custom key objects.

ViewModels can access other ViewModels using `readViewModel` and `watchViewModel`:

- **`readViewModel`**: Access another ViewModel without reactive connection
- **`watchViewModel`**: Create reactive dependency - automatically notifies when
  the watched ViewModel changes

When a ViewModel (the HostVM ) accesses another ViewModel (the SubVM ) via
watchViewModel , the framework automatically binds the SubVM \'s lifecycle to the
HostVM \'s UI observer (i.e., the State object of the StatefulWidget ).

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
    final authVM = readViewModel<AuthViewModel>();
    if (authVM?.isLoggedIn == true) {
      _fetchProfile(authVM!.userId);
    }
  }

  void setupReactiveAuth() {
    // Reactive access - auto-updates when auth changes
    final authVM = watchViewModel<AuthViewModel>();
    // This ViewModel will be notified when authVM changes
  }

  @override
  void onDependencyNotify(ViewModel viewModel) {
    // Called when watched ViewModels change
    if (viewModel is AuthViewModel) {
      // React to auth changes
      _handleAuthChange(viewModel);
    }
  }

  void manualListening() {
    final authVM = readViewModel<AuthViewModel>();
    // You can also manually listen to any ViewModel
    authVM?.listen(() {
      // Custom listener logic
      _handleAuthChange(authVM);
    });
  }
}
```

## 0.4.6

* The `view_model` package includes a powerful DevTools extension that provides
+  real-time monitoring and debugging capabilities for your ViewModels during
+  development.

-When a ViewModel (the HostVM ) accesses another ViewModel (the SubVM ) via watchViewModel , the
-framework automatically binds the SubVM \'s lifecycle to the HostVM \'s UI observer (i.e., the State
-object of the StatefulWidget ).
+create `devtools_options.yaml` in root directory of project.

-This means both the SubVM and the HostVM are directly managed by the lifecycle of the same State
-object. When this State object is disposed, if neither the SubVM nor the HostVM has other observers,
-they will be disposed of together automatically.
+```yaml
+description: This file stores settings for Dart & Flutter DevTools.
+documentation: https://docs.flutter.dev/tools/devtools/extensions#configure-extension-enablement-states
+extensions:
+  - view_model: true
+```

-This mechanism ensures clear dependency relationships between ViewModels and enables efficient,
-automatic resource management.
+![](https://i.imgur.com/5itXPYD.png)
+![](https://imgur.com/83iOQhy.png)

-```dart
-class UserProfileViewModel extends ViewModel {
-  void loadData() {
-    // One-time access without listening
-    final authVM = readViewModel<AuthViewModel>();
-    if (authVM?.isLoggedIn == true) {
-      _fetchProfile(authVM!.userId);
-    }
-  }
+* Breaking change: rename `initConfig` to `initialize`

-  void setupReactiveAuth() {
-    // Reactive access - auto-updates when auth changes
-    final authVM = watchViewModel<AuthViewModel>();
-    // This ViewModel will be notified when authVM changes
-  }
+## 0.4.5

-  @override
-  void onDependencyNotify(ViewModel viewModel) {
-    // Called when watched ViewModels change
-    if (viewModel is AuthViewModel) {
-      // React to auth changes
-      _handleAuthChange(viewModel);
-    }
-  }
+* Add `DefaultViewModelFactory` for convenient and generic ViewModel factory
+  creation.

-  void manualListening() {
-    final authVM = readViewModel<AuthViewModel>();
-    // You can also manually listen to any ViewModel
-    authVM?.listen(() {
-      // Custom listener logic
-      _handleAuthChange(authVM);
-    });
-  }
-}
-```
+## 0.4.4

-## 0.4.6
+* Add `ViewModel.maybeRead`

-* The `view_model` package includes a powerful DevTools extension that provides real-time monitoring
-  and debugging capabilities for your ViewModels during development.
+## 0.4.3

-create `devtools_options.yaml` in root directory of project.
+* Add `maybeWatchViewModel` and `maybeReadViewModel`
+* update `watchViewModel` find logic

-```yaml
-description: This file stores settings for Dart & Flutter DevTools.
-documentation: https://docs.flutter.dev/tools/devtools/extensions#configure-extension-enablement-states
-extensions:
-  - view_model: true
-```
+```dart
+VM watchViewModel<VM extends ViewModel>({
+  ViewModelFactory<VM>? factory,
+  Object? key,
+  Object? tag,
+});
+```

-![](https://i.imgur.com/5itXPYD.png)
-![](https://imgur.com/83iOQhy.png)
+| Parameter Name | Type                    | Optional | Description                                                                                                                                           |
+|----------------|-------------------------|----------|-------------------------------------------------------------------------------------------------------------------------------------------------------|
+| `factory`      | `ViewModelFactory<VM>?` | ✅        | Provides the construction method for the ViewModel. Optional; if an                                                                                   |
+|                |                         |          | existing instance is not found in the cache, it will be used to create a new                                                                          |
+|                |                         |          | one.                                                                                                                                                  |
+| `key`          | `String?`               | ✅        | Specifies a unique key to support sharing the same ViewModel instance.                                                                                |
+|                |                         |          | First, it tries to find an instance with the same key in the cache.                                                                                   |
+| `tag`          | `Object?`               | ✅        | Add a tag for ViewModel instance. get tag by `viewModel.tag`. and  it\'s                                                                              |
+|                |                         |          | used by find ViewModel by `watchViewModel(tag:tag)`.                                                                                                  |

-* Breaking change: rename `initConfig` to `initialize`
+__🔍 Lookup Logic Priority (Important)__
+The internal lookup and creation logic of `watchViewModel` is as follows
+(executed in priority order):

-## 0.4.5
+1. If a key is passed in:

-* Add `DefaultViewModelFactory` for convenient and generic ViewModel factory creation.
+* First, attempt to find an instance with the same key in the cache.
+* If a factory exists, use the factory to get a new instance.
+* If no factory is found and no instance is found, an error will be thrown.

-## 0.4.4
+2. If a tag is passed in, attempt to find the latest created instance which has
+   the same tag in the cache.
+3. If nothing passed in, attempt to find the latest created instance of this
+   type in the cache.

-* Add `ViewModel.maybeRead`
+> __⚠️ If no ViewModel instance of the specified type is found, an error will be
+thrown. Ensure that the ViewModel has been correctly created and registered
+before use.__

-## 0.4.3
+## 0.4.2

-* Add `maybeWatchViewModel` and `maybeReadViewModel`
-* update `watchViewModel` find logic
+* Support find existing ViewModel by tag

-```dart
-VM watchViewModel<VM extends ViewModel>({
-  ViewModelFactory<VM>? factory,
-  Object? key,
-  Object? tag,
-});
-```
+set tag in `ViewModelFactory.getTag()`:

-| Parameter Name | Type                    | Optional | Description                                                                                                                                           |
-|----------------|-------------------------|----------|-------------------------------------------------------------------------------------------------------------------------------------------------------|
-| `factory`      | `ViewModelFactory<VM>?` | ✅        | Provides the construction method for the ViewModel. Optional; if an existing instance is not found in the cache, it will be used to create a new one. |
-| `key`          | `String?`               | ✅        | Specifies a unique key to support sharing the same ViewModel instance. First, it tries to find an instance with the same key in the cache.            |
-| `tag`          | `Object?`               | ✅        | Add a tag for ViewModel instance. get tag by `viewModel.tag`. and  it\'s used by find ViewModel by `watchViewModel(tag:tag)`.                          |
+```dart
+class MyViewModelFactory extends ViewModelFactory<MyViewModel> {

-__🔍 Lookup Logic Priority (Important)__
-The internal lookup and creation logic of `watchViewModel` is as follows (executed in priority
-order):
+  @override
+  Object? getTag() {
+    return \'tag\';
+  }
+}
+```

-1. If a key is passed in:
+find existing ViewModel by tag:

-* First, attempt to find an instance with the same key in the cache.
-* If a factory exists, use the factory to get a new instance.
-* If no factory is found and no instance is found, an error will be thrown.
+```dart
+late final MyViewModel viewModel;

-2. If a tag is passed in, attempt to find the latest created instance which has the same tag
-   in the cache.
-3. If nothing passed in, attempt to find the latest created instance of this type
-   in the cache.
+@override
+void initState() {
+  super.initState();
+  viewModel = watchViewModel<MyViewModel>(tag: \'tag\');
+}
+```

-> __⚠️ If no ViewModel instance of the specified type is found, an error will be thrown. Ensure
-that the ViewModel has been correctly created and registered before use.__
+## 0.4.1

-## 0.4.2
+_Breaking change:_

-* Support find existing ViewModel by tag
+* Use `recycleViewModel` instead of `refreshViewModel`.

-set tag in `ViewModelFactory.getTag()`:
+## 0.4.0

-```dart
-class MyViewModelFactory extends ViewModelFactory<MyViewModel> {
+_Breaking change:_

-  @override
-  Object? getTag() {
-    return \'tag\';
-  }
-}
-```
+* Use `ViewModel` instead of `StatelessViewModel`.
+* Use `StateViewModel` instead of `ViewModel`.
+* Use either `watchViewModel` or `readViewModel` instead of `getViewModel`/
+  `requireExistingViewModel`.
+* Use `StateViewModel.listenState` instead of `ViewModel.listen`.
+* Use `ViewModel.listen` instead of `ViewModel.addListener`.

-find existing ViewModel by tag:
+* Support `ViewModel.read<T>` to read existing view model globally.

-```dart
-late final MyViewModel viewModel;
+## 0.3.0

-@override
-void initState() {
-  super.initState();
-  viewModel = watchViewModel<MyViewModel>(tag: \'tag\');
-}
-```
+* transfer to https://github.com/lwj1994/flutter_view_model. thank
+  to [Miolin](https://github.com/Miolin)