# view_model

[![Pub Version](https://img.shields.io/pub/v/view_model)](https://github/lwj1994/flutter_view_model) [![Codecov (with branch)](https://img.shields.io/codecov/c/github/lwj1994/flutter_view_model/main)](https://app.codecov.io/gh/lwj1994/flutter_view_model/tree/main)  

[English Doc](README.md)

我衷心感谢 [Miolin](https://github.com/Miolin) 将 [ViewModel](https://pub.dev/packages/view_model)
包的权限委托给我，并转移其所有权。这种支持无比珍贵，我很兴奋能推动它持续发展。

## 特性

- **简洁轻量**：架构简洁，资源开销极小，确保高性能表现。
- **透明实现**：基于 `StreamController` 和 `setState` 构建，内部逻辑简单易懂，无隐藏的复杂部分。
- **自动资源释放**：资源会随着 `StatefulWidget` 的 `State` 自动释放，简化了内存管理。
- **跨组件共享**：可在多个 `StatefulWidget` 之间共享，提升代码的可复用性和模块化程度。

> **注意**：`ViewModel` 旨在仅绑定到 `StatefulWidget` 的 `State`。由于 `StatelessWidget`
> 不维护状态，它们与这种绑定机制不兼容。

## 核心概念

- **ViewModel**：作为状态管理的核心。它持有应用程序状态，并在状态发生变化时通知已注册的监听器。
- **ViewModelFactory**：定义 `ViewModel` 的实例化和配置方式。
- **watchViewModel**：创建一个新的 `ViewModel` 实例或获取现有的实例，并自动触发 `setState`。
- **readViewModel**：获取现有的 `ViewModel`，或者使用工厂创建一个，不会触发 `setState`。

## 无状态和有状态的 ViewModel

默认情况下，`ViewModel` 以无状态模式运行。

### 无状态 ViewModel

- **简化使用**：是一种轻量级的选项，没有内部的 `state`。
- **更改通知**：数据更改通过 `notifyListeners()` 方法通知监听器。

### 有状态 ViewModel

- **面向状态**：必须持有一个内部的 `state` 对象。
- **不可变性原则**：`state` 是不可变的，确保数据的完整性和可预测性。
- **状态更新**：通过 `setState()` 方法进行状态更改，这会触发组件重建。

## 分步指南

使用 `view_model` 包非常简单。按照以下四个步骤操作：

添加依赖项：

```yaml
dependencies:
  view_model: ^0.4.0
```

### 1. 定义一个状态类（用于有状态 ViewModel）

对于有状态 ViewModel，首先创建一个不可变的状态类：

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

> **提示**：如果不需要管理复杂的状态，可以跳过此步骤，使用无状态 ViewModel（请参阅步骤 2）。

### 2. 创建一个 ViewModel

对于无状态场景，扩展 `ViewModel<T>`；对于有状态管理，扩展 `StateViewModel`。

**示例：无状态 ViewModel**

```dart
import 'package:view_model/view_model.dart';

class MyViewModel extends ViewModel {
  String name = "Initial Name";

  void updateName(String newName) {
    name = newName;
    notifyListeners();
  }
}
```

**示例：有状态 ViewModel**

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
    debugPrint('Disposed MyViewModel: $state');
  }
}
```

### 3. 实现一个 ViewModelFactory

使用 `ViewModelFactory` 指定 `ViewModel` 的实例化方式：

```dart
class MyViewModelFactory with ViewModelFactory<MyViewModel> {
  final String initialName;

  MyViewModelFactory({this.initialName = ""});

  @override
  MyViewModel build() => MyViewModel(state: MyState(name: initialName));

  // 可选：启用单例共享。仅在 key() 返回 null 时适用。
  @override
  bool singleton() => true;

  // 可选：基于自定义键共享 ViewModel。
  @override
  String? key() => initialName;
}
```

### 4. 将 ViewModel 集成到你的组件中

在 `StatefulWidget` 中，使用 `watchViewModel` 来访问 ViewModel：

```dart
import 'package:view_model/view_model.dart';

class _MyPageState extends State<MyPage> with ViewModelStateMixin<MyPage> {
  MyViewModel get viewModel =>
      watchViewModel<MyViewModel>(factory: MyViewModelFactory(initialName: "Hello"));

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

> **注意**：还支持其他功能，如更改监听、ViewModel 刷新和跨页面共享。有关详细信息，请参阅以下部分。

## 高级 API

### 监听状态变化

```dart
@override
void initState() {
  super.initState();
  final dispose = viewModel.listenState(onChanged: (prev, next) {
    print('State changed: $prev -> $next');
  });

  final dispose2 = viewModel.listen(onChanged: () {
    print('viewModel notifyListeners');
  });
}
```

### 获取现有的 ViewModel

使用 `readViewModel` 获取现有的 ViewModel。

```dart
// 查找新创建的 <MyViewModel> 实例
MyViewModel get viewModel => readViewModel<MyViewModel>();

// 按键查找 <MyViewModel> 实例
MyViewModel get viewModel => readViewModel<MyViewModel>(key: "my-key");

// 如果找不到（"my-key"），将回退到使用 MyViewModelFactory 创建实例
MyViewModel get viewModel =>
    readViewModel<MyViewModel>(key: "my-key", factory: MyViewModelFactory());
```

全局读取现有的 ViewModel：

```dart

final T vm = ViewModel.read<T>(key: "shareKey");
```

### 手动回收 ViewModel


```dart
MyViewModel get viewModel =>
    watchViewModel<MyViewModel>(key: "my-key", factory: MyViewModelFactory());

void refresh() {
  recycleViewModel(viewModel);

  // 再次调用的话，这将获取一个新实例
  viewModel;
}
```

## 关于部分刷新

状态管理器无需处理部分 UI 刷新 —— Flutter 引擎会自动执行 UI 差异比较。
一个组件的 `build` 方法只是一个配置步骤，触发它不会带来显著的性能开销。

要实现细粒度的更新，我们可以使用 `ValueListenableBuilder`。

```dart
@override
Widget build(BuildContext context) {
  return ValueNotifierBuilder(
    valueListenable: _notifier,
    builder: (context, value, child) {
      return Text(value);
    },
  );
}
``` 