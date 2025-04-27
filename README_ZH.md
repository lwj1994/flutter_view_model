# view_model

[![Static Badge](https://img.shields.io/badge/pub-0.3.0-brightgreen)](https://pub.dev/packages/view_model) [![Codecov (with branch)](https://img.shields.io/codecov/c/github/lwj1994/flutter_view_model/main)](https://app.codecov.io/gh/lwj1994/flutter_view_model/tree/main)

[中文文档](README_ZH.md)

我要向 [Miolin](https://github.com/Miolin)
表示诚挚的感谢，感谢他将 [view_model](https://pub.dev/packages/view_model)
包的权限托付给我，并转让了所有权。这份支持意义重大，我非常激动能够推动它持续发展。谢谢！

## 特性

- **简洁轻量**：拥有简洁的架构，资源占用极少，确保高效运行。
- **逻辑透明**：基于 `StreamController` 和 `setState` 构建，内部逻辑清晰易懂，不存在隐藏的复杂机制。
- **自动资源释放**：会随着 `StatefulWidget` 的 `State` 自动释放资源，简化了内存管理。
- **跨组件共享**：可以在多个 `StatefulWidget` 之间共享，促进代码复用和模块化。

> **重要提示**：`ViewModel` 仅设计用于绑定 `StatefulWidget` 的 `State`。由于 `StatelessWidget`
> 不维护状态，因此不支持这种绑定机制。

## 核心概念

- **ViewModel**：作为状态管理的核心，负责持有应用程序的状态，并在状态发生变化时通知注册的监听器。
- **ViewModelFactory**：定义 `ViewModel` 的实例化逻辑，指定如何创建和配置它们。
- **getViewModel**：一个实用函数，用于创建新的 `ViewModel` 实例或获取现有的实例，方便在应用程序中访问视图模型。

## 有状态和无状态 ViewModel

默认情况下，`ViewModel` 以有状态模式运行。

### 有状态 ViewModel

- **以状态为中心**：必须持有一个内部的 `state` 对象。
- **不可变原则**：`state` 设计为不可变的，确保数据的完整性和可预测性。
- **状态更新**：通过 `setState()` 方法修改状态，该方法会触发关联小部件的重建。

### 无状态 ViewModel

- **简化方案**：提供了一种更轻量级的替代方案，无需维护内部 `state`。
- **变更通知**：通过调用 `notifyListeners()` 方法将数据变更通知给监听器。

## 使用 ViewModel 的分步指南

使用 `view_model` 包是一个简单直接的过程。遵循以下四个步骤：

```yaml
dependencies:
  view_model: ^0.3.0
```

### 1. 定义状态类（适用于有状态 ViewModel）

对于有状态的视图模型，首先创建一个不可变的状态类：

```dart
class MyState {
  final String name;

  const MyState({required this.name});

  MyState copyWith({String? name}) =>
      MyState(
        name: name ?? this.name,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          (other is MyState && runtimeType == other.runtimeType && name == other.name);

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => 'MyState{name: $name}';
}
```

> **专业提示**：如果你的用例不需要管理复杂的状态，可以跳过此步骤，选择使用无状态 ViewModel（请参阅步骤
> 2）。

### 2. 创建 ViewModel

通过继承 `ViewModel<T>` 进行有状态管理，或继承 `StatelessViewModel` 进行无状态管理：

**示例：有状态 ViewModel**

```dart
import 'package:view_model/view_model.dart';

class MyViewModel extends ViewModel<MyState> {
  MyViewModel({required super.state});

  void updateName(String newName) {
    setState(state.copyWith(name: newName));
  }

  @override
  void dispose() async {
    super.dispose();
    debugPrint('Disposed MyViewModel: $state');
  }
}
```

**示例：无状态 ViewModel**

```dart
import 'package:view_model/view_model.dart';

class MyViewModel extends StatelessViewModel {
  String name = "Initial Name";

  void updateName(String newName) {
    name = newName;
    notifyListeners();
  }
}
```

### 3. 实现 ViewModelFactory

使用 `ViewModelFactory` 来指定如何实例化你的 `ViewModel`：

```dart
class MyViewModelFactory with ViewModelFactory<MyViewModel> {
  final String initialName;

  MyViewModelFactory({this.initialName = ""});

  @override
  MyViewModel build() => MyViewModel(state: MyState(name: initialName));

  // 可选：启用单例共享。仅当 key() 返回 null 时适用。
  @override
  bool singleton() => true;

  // 可选：根据自定义键共享 ViewModel。
  @override
  String? key() => initialName;
}
```

### 4. 将 ViewModel 集成到你的小部件中

在 `StatefulWidget` 中，使用 `getViewModel` 来访问视图模型：

```dart
import 'package:view_model/view_model.dart';

class _MyPageState extends State<MyPage> with ViewModelStateMixin<MyPage> {
  MyViewModel get viewModel =>
      getViewModel<MyViewModel>(factory: MyViewModelFactory(initialName: "Hello"));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(viewModel.state.name),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => viewModel.updateName("New Name"),
        child: Icon(Icons.refresh),
      ),
    );
  }
}
```

> **注意**：还支持诸如监听变更、刷新视图模型和跨页面共享等附加功能。请参阅以下部分以获取更多详细信息。

## 高级 API

### 监听状态变化

```dart
@override
void initState() {
  super.initState();
  viewModel.listen(onChanged: (prev, next) {
    print('State changed: $prev -> $next');
  });
}
```

### 获取现有 ViewModel

**选项 1**：使用 `getViewModel` 来获取现有的视图模型（如果未找到则创建一个新的）：

```dart
MyViewModel get viewModel =>
    getViewModel<MyViewModel>(factory: MyViewModelFactory(
      key: "my-key",
    ));
```

**选项 2**：使用 `requireExistingViewModel` 仅获取现有的视图模型（如果未找到则抛出异常）：

```dart
// 查找新创建的 <MyViewModel> 实例
MyViewModel get viewModel => requireExistingViewModel<MyViewModel>();

// 按键查找 <MyViewModel> 实例
MyViewModel get viewModel => requireExistingViewModel<MyViewModel>(key: "my-key");
```

### 刷新 ViewModel

创建一个新的视图模型实例：

```dart
void refresh() {
  refreshViewModel(viewModel);

  // 这将获取一个新的实例
  viewModel = getViewModel<MyViewModel>(
    factory: MyViewModelFactory(
      key: "my-key",
    ),
  );
}
``` 