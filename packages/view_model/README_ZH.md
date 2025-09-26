# view_model

[![Pub Version](https://img.shields.io/pub/v/view_model)](https://pub.dev/packages/view_model) [![Codecov (with branch)](https://img.shields.io/codecov/c/github/lwj1994/flutter_view_model/main)](https://app.codecov.io/gh/lwj1994/flutter_view_model/tree/main)

[更新日志](CHANGELOG.md)

[English Doc](README.md) | [中文文档](README_ZH.md)
> 感谢 [Miolin](https://github.com/Miolin) 将
> [view_model](https://pub.dev/packages/view_model) 包的权限转移给我。

---

## 1. 基本介绍

### 1.1 什么是 ViewModel？

`view_model` 是 Flutter 应用程序最简单的状态管理解决方案。

### 1.2 核心特性

该库通过 Flutter 特定的增强功能扩展了传统的 ViewModel 模式：

- **轻量且易于使用**：最少的依赖和极其简单的 API，便于快速集成
- **自动资源管理**：当没有 Widget 绑定到 ViewModel 时，ViewModel 会自动销毁，防止内存泄漏
- **高效的实例共享**：在多个 Widget 之间共享同一个 ViewModel 实例，具有 O(1) 查找性能
- **Widget 生命周期集成**：通过 `ViewModelStateMixin` 与 Flutter 的 Widget 生命周期无缝集成

> **重要提示**：`ViewModel` 仅支持绑定到 `StatefulWidget`。这是因为
`StatelessWidget` 没有独立的生命周期，无法支持 `ViewModel` 的自动
> 销毁和状态监听机制。

> * `watchViewModel` 和 `readViewModel` 会绑定到 ViewModel。
> * 当没有 Widget 绑定到 ViewModel 时，ViewModel 会自动销毁。

### 1.3 关于局部更新

不支持局部更新，因为本质上没什么大的收益：https://github.com/lwj1994/flutter_view_model/issues/13
### 1.4 API 快速概览

ViewModel 的方法很简单：

| 方法                    | 描述                     |
|-----------------------|------------------------|
| `watchViewModel<T>()` | 绑定到 ViewModel 并自动刷新 UI |
| `readViewModel<T>()`  | 绑定到 ViewModel 但不触发 UI 刷新 |
| `ViewModel.read<T>()` | 全局读取现有实例               |
| `recycleViewModel()`  | 主动销毁特定实例               |
| `listenState()`       | 监听状态对象的变化              |
| `listen()`            | 监听 `notifyListeners` 调用 |

## 2. 基本用法

本节将指导您完成 `view_model` 最基本的使用过程，作为
上手此库的最佳起点。

### 2.1 添加依赖

首先，将 `view_model` 添加到您项目的 `pubspec.yaml` 文件中：

```yaml
dependencies:
  flutter:
    sdk: flutter
  view_model: ^0.4.6 # 请使用最新版本
```

然后运行 `flutter pub get`。

### 2.2 创建 ViewModel

继承 `ViewModel` 类来创建您的业务逻辑单元。

```dart
import 'package:view_model/view_model.dart';
import 'package:flutter/foundation.dart'; // For debugPrint

class MySimpleViewModel extends ViewModel {
  String _message = "Initial Message";
  int _counter = 0;

  String get message => _message;

  int get counter => _counter;

  void updateMessage(String newMessage) {
    _message = newMessage;
    notifyListeners(); // 通知监听者数据已更新
  }

  void incrementCounter() {
    _counter++;
    notifyListeners(); // 通知监听者数据已更新
  }

  @override
  void dispose() {
    // 在此清理资源，例如关闭 StreamControllers 等
    debugPrint('MySimpleViewModel disposed');
    super.dispose();
  }
}
```

在这个例子中，`MySimpleViewModel` 管理一个 `message` 字符串和一个 `counter` 整数。当这些
值通过其方法更新时，会调用 `notifyListeners()` 来通知任何正在监听此 `ViewModel` 的 Widget 进行重建。

### 2.3 创建 ViewModelFactory

`ViewModelFactory` 负责实例化 `ViewModel`。每个 `ViewModel` 类型通常
需要一个对应的 `Factory`。

```dart
import 'package:view_model/view_model.dart';
// 假设 MySimpleViewModel 已如上定义

class MySimpleViewModelFactory with ViewModelFactory<MySimpleViewModel> {
  @override
  MySimpleViewModel build() {
    // 返回一个新的 MySimpleViewModel 实例
    return MySimpleViewModel();
  }
}
```

### 2.4 在 Widget 中使用 ViewModel

在您的 `StatefulWidget` 中，通过混入 `ViewModelStateMixin` 来集成和使用 `ViewModel`。

1. **混入 `ViewModelStateMixin`**：让您的 `State` 类混入
   `ViewModelStateMixin<YourWidget>`。
2. **使用 `watchViewModel`**：在 `State` 中通过 `watchViewModel`
   方法获取或创建 `ViewModel` 实例。此方法会自动处理 `ViewModel` 的生命周期和依赖。

```dart
import 'package:flutter/material.dart';
import 'package:view_model/view_model.dart';

// 假设 MySimpleViewModel 和 MySimpleViewModelFactory 已定义

class MyPage extends StatefulWidget {
  const MyPage({super.key});

  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage>
    with ViewModelStateMixin<MyPage> {
  // 1. 混入 Mixin

  late final MySimpleViewModel simpleVM;

  @override
  void initState() {
    super.initState();
    // 2. 在 initState 中获取 ViewModel
    // 当 MyPage 第一次构建时，MySimpleViewModelFactory 的 build() 方法会被调用来创建实例。
    // 当 MyPage 被销毁时，如果此 viewModel 没有其他监听者，它也会被销毁。
    simpleVM =
        watchViewModel<MySimpleViewModel>(factory: MySimpleViewModelFactory());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(simpleVM.message)), // 直接访问 ViewModel 的属性
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text('按钮按下次数：${simpleVM.counter} 次'), // 访问 ViewModel 的属性
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                simpleVM.updateMessage("消息已更新！"); // 调用 ViewModel 的方法
              },
              child: const Text('更新消息'),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => simpleVM.incrementCounter(), // 调用 ViewModel 的方法
        tooltip: '增加',
        child: const Icon(Icons.add),
      ),
    );
  }
}
```

### 2.5 监听 ViewModel 通知

除了 UI 会自动响应 `ViewModel` 更新外，您还可以通过 `listen` 方法监听其
`notifyListeners()` 调用并执行副作用，例如显示
`SnackBar` 或导航。

```dart
// 在 State 的 initState 或其他适当方法中
late VoidCallback _disposeViewModelListener;

@override
void initState() {
  super.initState();

  // 获取 ViewModel 实例（通常在 initState 中获取一次或通过 getter 访问）
  final myVm = watchViewModel<MySimpleViewModel>(factory: MySimpleViewModelFactory());

  _disposeViewModelListener = myVm.listen(onChanged: () {
    print('MySimpleViewModel 调用了 notifyListeners！当前计数器：${myVm.counter}');
    // 例如：ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('执行了操作！')));
  });
}

@override
void dispose() {
  _disposeViewModelListener(); // 清理监听器以防止内存泄漏
  super.dispose();
}
```

**注意**：`listen` 返回一个 `VoidCallback` 用于取消监听器。确保在
`State` 的 `dispose` 方法中调用它。

## 3. 详细参数说明

### 3.1 ViewModelFactory

`ViewModelFactory<T>` 是用于创建、配置和识别 ViewModel
实例的工厂类。它通过混入（with）使用。

| 方法/属性      | 类型        | 可选         | 描述                                                                                                                                            |
|------------|-----------|------------|-----------------------------------------------------------------------------------------------------------------------------------------------|
| `build()`  | `T`       | ❌ 必须实现     | 创建 ViewModel 实例的工厂方法。通常在这里传递构造函数参数。                                                                                                          |
| `key()`    | `String?` | ✅ 可选       | 为 ViewModel 提供唯一标识符。具有相同 key 的 ViewModel 将自动共享（推荐用于跨 widget/页面共享）。 | |                              |
| `getTag()` | `Object?` | ✅          | 为 ViewModel 实例添加标签。通过 `viewModel.tag` 获取标签。它用于通过 `watchViewModel(tag:tag)` 查找 ViewModel。                                                   |

```dart
class MyViewModelFactory with ViewModelFactory<MyViewModel> {
  // 您的自定义参数，通常传递给 MyViewModel
  final String initialName;

  MyViewModelFactory({required this.initialName});

  @override
  MyViewModel build() {
    return MyViewModel(name: initialName);
  }

  /// 共享 ViewModel 的 key。key 是唯一的，同一个 key 只会创建一个 ViewModel 实例。
  /// 如果 key 为 null，则不会发生共享。
  @override
  String? key() => "user-profile";
}
```

### 3.2 watchViewModel

`watchViewModel<T>()` 是核心方法之一，用于：获取或创建 ViewModel 实例并
在其变化时自动触发 `setState()` 重建 Widget。

```dart
VM watchViewModel<VM extends ViewModel>({
  ViewModelFactory<VM>? factory,
  String? key,
  Object? tag,
});
```

| 参数名       | 类型                      | 可选 | 描述                                                                                                                                           |
|-----------|-------------------------|----|----------------------------------------------------------------------------------------------------------------------------------------------|
| `factory` | `ViewModelFactory<VM>?` | ✅  | 提供 ViewModel 的构造方法。可选；如果在缓存中找不到现有实例，将使用它创建新实例。                                                                                             |
| `key`     | `String?`               | ✅  | 指定唯一键以支持共享同一个 ViewModel 实例。首先尝试在缓存中查找具有相同 key 的实例。                                                                                           |
| `tag`     | `Object?`               | ✅  | 为 ViewModel 实例添加标签。通过 `viewModel.tag` 获取标签。它用于通过 `watchViewModel(tag:tag)` 查找 ViewModel。                                                   |

__🔍 查找逻辑优先级（重要）__
`watchViewModel` 内部的查找和创建逻辑如下（按优先级执行
顺序）：

1. 如果传入了 key：
   * 首先，尝试在缓存中查找具有相同 key 的实例。
   * 如果存在工厂，使用工厂获取新实例。
   * 如果没有找到工厂且没有找到实例，将抛出错误。
2. 如果传入了 tag，尝试在缓存中查找具有相同 tag
   的最新创建实例。
3. 如果什么都没传入，尝试在缓存中查找此类型
   的最新创建实例。

> __⚠️ 如果找不到指定类型的 ViewModel 实例，将抛出错误。确保
在使用前已正确创建并注册了 ViewModel。__

✅ 一旦找到实例，`watchViewModel` 将自动注册监听并在其状态变化时调用
`setState()` 重建当前 Widget。

### 3.3 readViewModel

它具有与 `watchViewModel` 相同的参数，但不会触发 Widget 重建。适用于
需要读取 ViewModel 状态或执行一次性操作的场景。

### 3.4 ViewModel 生命周期

- `watchViewModel` 和 `readViewModel` 都会绑定到 ViewModel。
- 当没有 Widget 绑定到 ViewModel 时，它会自动销毁。

### 3.5 ViewModel 之间的访问

ViewModel 可以使用 `readViewModel` 和 `watchViewModel` 访问其他 ViewModel：

- **`readViewModel`**：访问另一个 ViewModel 而不建立响应式连接
- **`watchViewModel`**：创建响应式依赖 - 当被观察的 ViewModel 变化时自动通知

```dart
class UserProfileViewModel extends ViewModel {
  void loadData() {
    // 一次性访问，不监听
    final authVM = readViewModel<AuthViewModel>();
    if (authVM?.isLoggedIn == true) {
      _fetchProfile(authVM!.userId);
    }
  }
  
  void setupReactiveAuth() {
    // 响应式访问 - 当 auth 变化时自动更新
    final authVM = watchViewModel<AuthViewModel>();
    // 当 authVM 变化时，此 ViewModel 将收到通知
  }
  
  @override
  void onDependencyNotify(ViewModel viewModel) {
    // 当被观察的 ViewModel 变化时调用
    if (viewModel is AuthViewModel) {
      // 响应认证变化
      _handleAuthChange(viewModel);
    }
  }
  
  void manualListening() {
    final authVM = readViewModel<AuthViewModel>();
    // 您也可以手动监听任何 ViewModel
    authVM?.listen(() {
      // 自定义监听逻辑
      _handleAuthChange(authVM);
    });
  }
}
```

**注意**：
- 使用 `watchViewModel` 时，您将收到 `onDependencyNotify` 回调，当被观察的 ViewModel 变化时。


## 4. 有状态的 ViewModel (`StateViewModel<S>`)

当您的业务逻辑需要管理一个清晰的、结构化的状态对象时，`StateViewModel<S>` 是一个
更合适的选择。它强制持有一个不可变的 `state` 对象并通过
`setState` 方法更新状态。

### 4.1 定义状态类

首先，您需要定义一个状态类。强烈建议此类是不可变的，
通常通过提供 `copyWith` 方法来实现。

```dart
// example: lib/my_counter_state.dart
import 'package:flutter/foundation.dart';

@immutable // 推荐标记为不可变
class MyCounterState {
  final int count;
  final String statusMessage;

  const MyCounterState({this.count = 0, this.statusMessage = "Ready"});

  MyCounterState copyWith({int? count, String? statusMessage}) {
    return MyCounterState(
      count: count ?? this.count,
      statusMessage: statusMessage ?? this.statusMessage,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is MyCounterState &&
              runtimeType == other.runtimeType &&
              count == other.count &&
              statusMessage == other.statusMessage;

  @override
  int get hashCode => count.hashCode ^ statusMessage.hashCode;

  @override
  String toString() => 'MyCounterState{count: $count, statusMessage: $statusMessage}';
}
```

### 4.2 创建有状态的 ViewModel

继承 `StateViewModel<S>`，其中 `S` 是您定义的状态类的类型。

```dart
// example: lib/my_counter_view_model.dart
import 'package:view_model/view_model.dart';
import 'package:flutter/foundation.dart';
import 'my_counter_state.dart'; // 导入状态类

class MyCounterViewModel extends StateViewModel<MyCounterState> {
  // 构造函数必须通过 super 初始化状态
  MyCounterViewModel({required MyCounterState initialState}) : super(state: initialState);

  void increment() {
    // 使用 setState 更新状态，它会自动处理 notifyListeners
    setState(state.copyWith(count: state.count + 1, statusMessage: "已增加"));
  }

  void decrement() {
    if (state.count > 0) {
      setState(state.copyWith(count: state.count - 1, statusMessage: "已减少"));
    } else {
      setState(state.copyWith(statusMessage: "不能减少到零以下"));
    }
  }

  void reset() {
    // 您可以直接用新的 State 实例替换旧状态
    setState(const MyCounterState(count: 0, statusMessage: "已重置"));
  }

  @override
  void dispose() {
    debugPrint('已销毁 MyCounterViewModel，状态：$state');
    super.dispose();
  }
}
```

在 `StateViewModel` 中，您通过调用 `setState(newState)` 来更新状态。此方法用新状态替换
旧状态并自动通知所有监听者。

### 4.3 创建 ViewModelFactory

为您的 `StateViewModel` 创建对应的 `Factory`。

```dart
// example: lib/my_counter_view_model_factory.dart
import 'package:view_model/view_model.dart';
import 'my_counter_state.dart';
import 'my_counter_view_model.dart';

class MyCounterViewModelFactory with ViewModelFactory<MyCounterViewModel> {
  final int initialCount;

  MyCounterViewModelFactory({this.initialCount = 0});

  @override
  MyCounterViewModel build() {
    // 在 build 方法中创建并返回 ViewModel 实例，传入初始状态
    return MyCounterViewModel(
        initialState: MyCounterState(count: initialCount, statusMessage: "已初始化"));
  }
}
```

### 4.4 在 Widget 中使用有状态的 ViewModel

在 `StatefulWidget` 中使用有状态的 `ViewModel` 与使用无状态的 `ViewModel` 非常相似，
主要区别是您可以直接访问 `viewModel.state` 来获取当前
状态对象。

```dart
// example: lib/my_counter_page.dart
import 'package:flutter/material.dart';
import 'package:view_model/view_model.dart';
import 'my_counter_view_model.dart';
import 'my_counter_view_model_factory.dart';
// MyCounterState 将被 MyCounterViewModel 内部引用

class MyCounterPage extends StatefulWidget {
  const MyCounterPage({super.key});

  @override
  State<MyCounterPage> createState() => _MyCounterPageState();
}

class _MyCounterPageState extends State<MyCounterPage>
    with ViewModelStateMixin<MyCounterPage> {
  late final MyCounterViewModel counterVM;

  @override
  void initState() {
    super.initState();
    counterVM = watchViewModel<MyCounterViewModel>(
        factory: MyCounterViewModelFactory(initialCount: 10)); // 您可以传入初始值
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('有状态的 ViewModel 计数器')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              '计数：${counterVM.state.count}', // 直接访问状态的属性
              style: Theme
                  .of(context)
                  .textTheme
                  .headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '状态：${counterVM.state.statusMessage}', // 访问状态的其他属性
              style: Theme
                  .of(context)
                  .textTheme
                  .titleMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: () => counterVM.increment(),
            tooltip: '增加',
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            onPressed: () => counterVM.decrement(),
            tooltip: '减少',
            child: const Icon(Icons.remove),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.extended(
            onPressed: () => counterVM.reset(),
            tooltip: '重置',
            icon: const Icon(Icons.refresh),
            label: const Text("重置"),
          ),
        ],
      ),
    );
  }
}
```

---

## 5. DefaultViewModelFactory 快速工厂

### 5.1 何时使用

对于不需要复杂构造逻辑的简单 ViewModel，您可以直接使用此工厂。

### 5.2 用法

```dart

final factory = DefaultViewModelFactory<MyViewModel>(
  builder: () => MyViewModel(),
  isSingleton: true, // 可选
);
```

### 5.3 参数

- `builder`：创建 ViewModel 实例的函数。
- `key`：单例实例共享的自定义键。
- `tag`：用于标识 ViewModel 的自定义标签。
- `isSingleton`：是否使用单例模式。这只是为您设置唯一键的便捷方式。注意优先级低于 key 参数。

### 5.4 示例

```dart

final factory = DefaultViewModelFactory<CounterViewModel>(
  builder: () => CounterViewModel(),
);
final singletonFactory = DefaultViewModelFactory<CounterViewModel>(
  builder: () => CounterViewModel(),
  key: 'global-counter',
);
```

此工厂特别适用于不需要复杂构造
逻辑的简单 ViewModel。

---

## 6. DevTools 扩展

`view_model` 包包含一个强大的 DevTools 扩展，在开发过程中为您的 ViewModel 提供实时监控
和调试功能。

在项目根目录创建 `devtools_options.yaml`。

```yaml
description: This file stores settings for Dart & Flutter DevTools.
documentation: https://docs.flutter.dev/tools/devtools/extensions#configure-extension-enablement-states
extensions:
  - view_model: true
```


![](https://i.imgur.com/5itXPYD.png)
![](https://imgur.com/83iOQhy.png)