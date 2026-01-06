# ViewModel 依赖注入流程详解

本文档详细解释了 `view_model` 包如何利用 Dart 的 `Zone` 机制，实现在 `ViewModel` 的构造函数中安全地调用 `readViewModel` 或 `watchViewModel` 来获取其他 `ViewModel` 实例。

## 核心问题

在 Flutter 中，`State` 对象持有依赖注入的上下文。当一个 `ViewModel` 被创建时，我们需要一种方式将这个上下文（特别是依赖解析器）从 `State` 传递到 `ViewModel` 的构造函数内部。然而，`ViewModel` 的构造函数本身并没有直接访问 `State` 的能力。

## 解决方案：利用 `Zone` 机制

我们通过 Dart 的 `Zone` 来创建一个上下文环境，将依赖解析器“注入”到这个环境中。当 `ViewModel` 在这个环境中被创建和执行时，它内部的任何代码都可以从该环境中读取到这个解析器。

整个流程可以分为三个关键步骤：

### 1. 创建带有依赖解析器的 `Zone` (在 `extension.dart` 中)

当 `ViewModelStateMixin` 的 `_createViewModel` 方法被调用以创建 `ViewModel` 实例时，它不会直接调用 `_instanceController.getInstance`。相反，它会使用一个名为 `runWithResolver` 的辅助函数来包裹这个调用。

```dart
// in view_model/lib/src/view_model/extension.dart

T _createViewModel<T extends ViewModel>(ViewModelBuilder<T> builder) {
  // ...
  final res = runWithResolver(
    _onChildDependencyResolver, // 步骤 1.1: 传入解析器函数
    () => _instanceController.getInstance<T>( // 步骤 1.2: 在新的 Zone 中执行 ViewModel 的创建
      builder,
      name: name,
      key: key,
      creator: runtimeType.toString(),
    ),
  );
  // ...
  return res;
}
```

-   **`runWithResolver` 函数**: 这个函数（位于 `dependency_handler.dart`）是实现魔法的核心。它接收一个解析器函数 (`resolver`) 和一个要执行的主体函数 (`body`)。
-   它会创建一个新的 `Zone`，并将 `resolver` 函数存储在这个 `Zone` 的 `zoneValues` 中，使用一个私有的 `_resolverKey` 作为键。
-   然后，它在新创建的 `Zone` 中执行 `body` 函数。

```dart
// in view_model/lib/src/view_model/dependency_handler.dart

R runWithResolver<R>(DependencyResolver resolver, R Function() body) {
  return runZoned( // 创建一个新的 Zone
    body,
    zoneValues: {
      _resolverKey: resolver, // 将解析器存入 Zone
    },
  );
}
```

### 2. `ViewModel` 的创建与 `DependencyHandler` 的初始化

当 `runWithResolver` 中的 `body` 函数（即 `_instanceController.getInstance(...)`）被执行时，`ViewModel` 的构造函数被调用。

在 `ViewModel` 的构造函数中，会创建一个 `DependencyHandler` 实例。

```dart
// in view_model/lib/src/view_model/view_model.dart

abstract class ViewModel extends ChangeNotifier {
  ViewModel() {
    dependencyHandler = DependencyHandler(); // 步骤 2.1: 创建 DependencyHandler
    // ...
  }
  // ...
}
```

`DependencyHandler` 的构造函数设计得非常巧妙：它会尝试从**当前 `Zone`** 中获取依赖解析器。

```dart
// in view_model/lib/src/view_model/dependency_handler.dart

class DependencyHandler {
  DependencyHandler() {
    // 步骤 2.2: 从当前 Zone 中获取解析器
    _dependencyResolver = Zone.current[_resolverKey] as DependencyResolver?;
  }
  // ...
}
```

因为 `ViewModel` 的构造函数是在 `runWithResolver` 创建的那个特殊 `Zone` 中被调用的，所以 `Zone.current[_resolverKey]` 能够成功地获取到在第一步中存入的 `_onChildDependencyResolver` 函数。

### 3. 在 `ViewModel` 构造函数中解析依赖

现在，`ViewModel` 实例已经拥有了一个配置好 `_dependencyResolver` 的 `dependencyHandler`。

如果在 `ViewModel` 的构造函数或 `onInit` 方法中调用 `readViewModel<OtherViewModel>()`，会发生以下情况：

```dart
// in view_model/lib/src/view_model/view_model.dart

T readViewModel<T extends ViewModel>({String? name, Object? key}) {
  // 步骤 3.1: 调用 dependencyHandler 来获取 ViewModel
  return dependencyHandler.getViewModel<T>(
    () => ViewModel.create<T>(),
    name: name,
    key: key,
  );
}
```

`dependencyHandler.getViewModel` 方法会检查 `_dependencyResolver` 是否存在。如果存在，它就会调用这个解析器来获取 `OtherViewModel` 的实例。

```dart
// in view_model/lib/src/view_model/dependency_handler.dart

T getViewModel<T extends ViewModel>(...) {
  if (_dependencyResolver != null) {
    // 步骤 3.2: 执行从 Zone 中获取到的解析器
    return _dependencyResolver!<T>(...);
  }
  // ...
}
```

这个 `_dependencyResolver` 正是 `State` 端的 `_onChildDependencyResolver` 方法。该方法有能力从正确的 `BuildContext` 中创建或获取 `ViewModel` 实例，从而完成了整个依赖注入的闭环。

## 总结

通过 `runZoned`，我们像传递一个“隐式参数”一样，将 `State` 的依赖解析能力传递给了 `ViewModel` 的构造环境。这使得 `ViewModel` 在被创建的时刻，就已经具备了从正确的上下文中解析其他依赖的能力，完美解决了在构造函数中进行依赖注入的问题。