# view_model

[![Static Badge](https://img.shields.io/badge/pub-0.3.0-brightgreen)](https://pub.dev/packages/view_model) [![Codecov (with branch)](https://img.shields.io/codecov/c/github/lwj1994/flutter_view_model/main)](https://app.codecov.io/gh/lwj1994/flutter_view_model/tree/main)

[中文文档](README_ZH.md)

我衷心感谢 [Miolin](https://github.com/Miolin) 将 [ViewModel](https://pub.dev/packages/view_model) 软件包的权限托付给我，并转让了其所有权。这种支持无比珍贵，我非常激动能够推动它持续发展。谢谢！

## 特性
- **简洁轻量的设计**：拥有精简的架构，资源占用极少，确保了高效的性能表现。
- **透明的实现方式**：基于 `StreamController` 和 `setState` 构建，其内部逻辑简单直接，易于理解，不存在任何隐藏的复杂之处。
- **自动资源释放**：资源会随着 `StatefulWidget` 的 `State` 自动释放，简化了内存管理工作。
- **跨组件共享**：可在多个 `StatefulWidget` 之间共享，提升了代码的可复用性和模块化程度。

> **重要提示**：`ViewModel` 专门设计为仅与 `StatefulWidget` 的 `State` 绑定。由于 `StatelessWidget` 不维护状态，它们与这种绑定机制不兼容。

## 核心概念
- **ViewModel**：作为状态管理的核心存储库。它保存着应用程序的状态，并在状态发生变化时通知已注册的监听器。
- **ViewModel工厂（ViewModelFactory）**：定义了 `ViewModel` 的实例化逻辑，明确了它们的创建和配置方式。
- **获取ViewModel（getViewModel）**：这是一个实用函数，用于创建新的 `ViewModel` 实例或获取已有的实例，方便在应用程序中轻松访问ViewModel。

## 有状态和无状态ViewModel
默认情况下，`ViewModel` 以无状态模式运行。

### 无状态ViewModel
- **简化的方式**：提供了一种更轻量的选择，无需维护内部的 `state`。
- **变更通知**：通过调用 `notifyListeners()` 方法，将数据变更通知给监听器。

### 有状态ViewModel
- **以状态为核心**：必须持有一个内部的 `state` 对象。
- **不可变性原则**：`state` 被设计为不可变的，确保了数据的完整性和可预测性。
- **状态更新**：状态的修改通过 `setState()` 方法实现，该方法会触发相关联的组件进行重建。

## 使用ViewModel的分步指南
使用 `view_model` 软件包的过程非常简单明了。请按照以下四个步骤操作：

添加依赖项：
```yaml
dependencies:
  view_model: ^0.4.0
```

### 1. 定义状态类（适用于有状态ViewModel）
对于有状态的ViewModel，首先要创建一个不可变的状态类：
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

> **实用技巧**：如果你的用例不需要管理复杂的状态，你可以跳过这一步，选择使用无状态ViewModel（请参考步骤 2）。

### 2. 创建ViewModel
对于无状态场景，扩展 `ViewModel<T>`；对于有状态管理，扩展 `StateViewModel`。

**示例：无状态ViewModel**
```dart
import 'package:view_model/view_model.dart';

class MyViewModel extends ViewModel {
  String name = "初始名称";

  void updateName(String newName) {
    name = newName;
    notifyListeners();
  }
}
```

**示例：有状态ViewModel**
```dart
import 'package:view_model/view_model.dart';

class MyViewModel extends StateViewModel<MyState> {
  MyViewModel({required super.state});

  void updateName(String newName) {
    setState(state.copyWith(name: newName));
  }

  @override
  void dispose() async {
    super.dispose();
    debugPrint('已释放 MyViewModel：$state');
  }
}
```

### 3. 实现ViewModel工厂
使用 `ViewModelFactory` 来指定如何实例化你的 `ViewModel`：
```dart
class MyViewModelFactory with ViewModelFactory<MyViewModel> {
  final String initialName;

  MyViewModelFactory({this.initialName = ""});

  @override
  MyViewModel build() => MyViewModel(state: MyState(name: initialName));

  // 可选：启用单例共享。仅在 key() 返回 null 时适用。
  @override
  bool singleton() => true;

  // 可选：基于自定义键共享ViewModel。
  @override
  String? key() => initialName;
}
```

### 4. 将ViewModel集成到你的组件中
在 `StatefulWidget` 中，使用 `getViewModel` 来访问ViewModel：
```dart
import 'package:view_model/view_model.dart';

class _MyPageState extends State<MyPage> with ViewModelStateMixin<MyPage> {
  MyViewModel get viewModel =>
      getViewModel<MyViewModel>(factory: MyViewModelFactory(initialName: "Hello"));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      主体: Center(
        child: Text(viewModel.state.name),
      ),
      悬浮操作按钮: FloatingActionButton(
        onPressed: () => viewModel.updateName("新名称"),
        child: Icon(Icons.refresh),
      ),
    );
  }
}
```

> **注意**：还支持诸如监听变更、刷新ViewModel和跨页面共享等额外功能。更多详细信息请参考以下章节。

## 高级 API

### 监听状态变更
```dart
@override
void initState() {
  super.initState();
  viewModel.listen(onChanged: (prev, next) {
    print('状态已变更：$prev -> $next');
  });
}
```

### 获取已有的ViewModel
**选项 1**：使用 `getViewModel` 来获取已有的ViewModel（如果未找到则创建一个新的）：
```dart
MyViewModel get viewModel =>
    getViewModel<MyViewModel>(factory: MyViewModelFactory(
      key: "my-key",
    ));
```

**选项 2**：使用 `requireExistingViewModel` 仅获取已有的ViewModel（如果未找到则抛出异常）：
```dart
// 查找新创建的 <MyViewModel> 实例
MyViewModel get viewModel => requireExistingViewModel<MyViewModel>();

// 按键查找 <MyViewModel> 实例
MyViewModel get viewModel => requireExistingViewModel<MyViewModel>(key: "my-key");
```

### 刷新ViewModel
创建ViewModel的新实例：
```dart
void refresh() {
  refreshViewModel(viewModel);

  // 这将获取一个新实例
  viewModel = getViewModel<MyViewModel>(
    factory: MyViewModelFactory(
      key: "my-key",
    ),
  );
}
``` 