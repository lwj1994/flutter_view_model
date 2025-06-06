# view_model

[![Pub Version](https://img.shields.io/pub/v/view_model)](https://pub.dev/packages/view_model) [![Codecov (with branch)](https://img.shields.io/codecov/c/github/lwj1994/flutter_view_model/main)](https://app.codecov.io/gh/lwj1994/flutter_view_model/tree/main)

[English Doc](README.md)

> 感谢 [Miolin](https://github.com/Miolin) 将 [ViewModel](https://pub.dev/packages/view_model)
> 包的权限转移给我。

---

`view_model` 是一个轻量级的 Flutter 状态管理库，旨在提供简洁、高效的解决方案。

## 1. 基本介绍

### 1.1 什么是 ViewModel？

### 1.2 核心特性

* **轻量易用**：以最少的依赖和极简的 API 为设计目标，上手快，侵入性低。
* **自动资源管理**：当没有任何 Widget 绑定(watch/read) 一个 `ViewModel` 实例时，该实例会自动调用
  `dispose` 方法并被销毁，有效防止内存泄漏。
* **便捷共享**：支持跨多个 Widget 共享同一个 `ViewModel` 实例，并且能以 O(1) 的时间复杂度高效查找。

> **重要提示**：`ViewModel` 仅支持绑定到 `StatefulWidget`。这是因为 `StatelessWidget` 没有独立的生命周期，无法支持
`ViewModel` 的自动销毁和状态监听机制。


> * `watchViewModel` 和 `readViewModel` 会绑定 ViewModel
> * 当没有任何 Widget 绑定 ViewModel 时，viewModel 会自动销毁。

### 1.3 Api 速览

ViewModel 的方法很简单：

| 方法                    | 说明                     |
|-----------------------|------------------------|
| `watchViewModel<T>()` | 绑定 ViewModel 并自动刷新 UI  |
| `readViewModel<T>()`  | 绑定 ViewModel，但不触发刷新 UI |
| `ViewModel.read<T>()` | 全局读取现有的实例              |
| `recycleViewModel()`  | 主动销毁某个实例               |
| `listenState()`       | 监听 state 对象变化          |
| `listen()`            | 监听 notifyListeners 调用  |

## 2. 基础用法

本节将引导您完成 `view_model` 最基础的使用流程。这是上手此库的最佳起点。

### 2.1 添加依赖

首先，将 `view_model` 添加到您项目的 `pubspec.yaml` 文件中：

```yaml
dependencies:
  flutter:
    sdk: flutter
  view_model: ^0.4.2 # 请使用最新版本
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

在这个例子中，`MySimpleViewModel` 管理一个 `message` 字符串和一个 `counter` 整数。当这些值通过其方法更新时，会调用
`notifyListeners()` 来通知任何正在监听此 `ViewModel` 的 Widget 进行重建。

### 2.3 创建 ViewModelFactory

`ViewModelFactory` 负责 `ViewModel` 的实例化。每个 `ViewModel` 类型通常需要一个对应的 `Factory`。

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

1. **混入 `ViewModelStateMixin`**：让您的 `State` 类混入 `ViewModelStateMixin<YourWidget>`。
2. **使用 `watchViewModel`**：在 `State` 中通过 `watchViewModel` 方法获取或创建 `ViewModel`
   实例。此方法会自动处理 `ViewModel` 的生命周期和依赖。

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

  // 2. 使用 watchViewModel 获取 ViewModel
  // 当 MyPage 第一次构建时，MySimpleViewModelFactory 的 build() 方法会被调用来创建实例。
  // 当 MyPage dispose 时，如果该 viewModel 没有其他监听者，它也会被 dispose。
  MySimpleViewModel get simpleVM =>
      watchViewModel<MySimpleViewModel>(factory: MySimpleViewModelFactory());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(simpleVM.message)), // 直接访问 ViewModel 的属性
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text('Button pressed: ${simpleVM.counter} times'), // 访问 ViewModel 的属性
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                simpleVM.updateMessage("Message Updated!"); // 调用 ViewModel 的方法
              },
              child: const Text('Update Message'),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => simpleVM.incrementCounter(), // 调用 ViewModel 的方法
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
```

### 2.5 监听 ViewModel 的通知

除了 UI 会自动响应 `ViewModel` 的更新外，您还可以通过 `listen` 方法来监听其 `notifyListeners()`
调用，并执行一些副作用，例如显示 `SnackBar`、导航等。

```dart
// 在 State 的 initState 或其他适当方法中
late VoidCallback _disposeViewModelListener;

@override
void initState() {
  super.initState();

  // 获取 ViewModel 实例 (通常在 initState 中获取一次，或通过 getter 访问)
  final myVm = watchViewModel<MySimpleViewModel>(factory: MySimpleViewModelFactory());

  _disposeViewModelListener = myVm.listen(onChanged: () {
    print('MySimpleViewModel called notifyListeners! Current counter: ${myVm.counter}');
    // 例如：ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Action performed!')));
  });
}

@override
void dispose() {
  _disposeViewModelListener(); // 清理监听器，防止内存泄漏
  super.dispose();
}
```

**注意**：`listen` 返回一个 `VoidCallback`，用于取消监听。请确保在 `State` 的 `dispose` 方法中调用它。

## 3. 详细参数讲解

### 3.1 ViewModelFactory

`ViewModelFactory<T>` 是用于创建、配置和识别 ViewModel 实例的工厂类。它通过混入（with）使用。

| 方法/属性     | 类型        | 是否可选   | 说明                                                                   |
|-----------|-----------|--------|----------------------------------------------------------------------|
| `build()` | `T`       | ❌ 必须实现 | 创建 ViewModel 实例的工厂方法。通常在这里传入构造参数。                                    |
| `key()`   | `String?` | ✅ 可选   | 为 ViewModel 提供唯一标识。具备相同 key 的 ViewModel 将自动共享（推荐用于跨 widget/page 共享）。 | |                              |

```dart
class MyViewModelFactory with ViewModelFactory<MyViewModel> {
  // 你的自定义参数。通常用于传递给 MyViewModel
  final String initialName;

  MyViewModelFactory({required this.initialName});

  @override
  MyViewModel build() {
    return MyViewModel(name: initialName);
  }

  /// 共享 ViewModel 的 key。key 是唯一的，同一个 key 只会创建一个 ViewModel 实例。
  /// 如果 key 为 null，则不共享
  @override
  String? key() => "user-profile";
}

```

### 3.2 watchViewModel

watchViewModel<T>() 是核心方法之一，它的作用是： 获取或创建一个 ViewModel 实例，并在其变化时自动触发
setState() 使 Widget 重建。

```dart
VM watchViewModel<VM extends ViewModel>({
  ViewModelFactory<VM>? factory,
  String? key,
});
```

| 参数名       | 类型                      | 是否可选 | 说明                                           |
|-----------|-------------------------|------|----------------------------------------------|
| `factory` | `ViewModelFactory<VM>?` | ✅    | 提供 ViewModel 的构建方式。可选，如果缓存中找不到现有实例时会使用它创建新的。 |
| `key`     | `String?`               | ✅    | 指定唯一键，支持共享同一个 ViewModel 实例。优先查找缓存中的实例。       |

__🔍 查找逻辑优先级（重要）__
`watchViewModel` 内部的查找与创建逻辑如下所示（按优先级执行）：

1. 如果传入了 key：
    * 优先尝试从缓存中查找具有相同 key 的实例。
2. 如果 factory 存在的话，通过用 factory 获取新实例。
3. 最后尝试从缓存中查找该类型最新创建的实例

> __⚠️如果找不到指定类型的 ViewModel 实例，将抛出异常。请确保在使用前已正确创建并注册了 ViewModel。__

✅ 一旦找到实例，watchViewModel 会自动注册监听，并在其状态发生变化时调用 setState() 重建当前 Widget。

### 3.3 readViewModel

和 `watchViewModel` 参数一致，区别是不会触发 Widget 重建。适用于需要一次性读取 ViewModel 状态或执行操作的场景。

### 3.4 ViewModel 的生命周期

* `watchViewModel` 和 `readViewModel` 都会绑定 ViewModel
* 当没有任何 Widget 绑定 ViewModel 时，会自动销毁。

## 4. 带状态的 ViewModel (`StateViewModel<S>`)

当您的业务逻辑需要管理一个明确的、结构化的状态对象时，`StateViewModel<S>` 是一个更合适的选择。它强制持有一个不可变的
`state` 对象，并通过 `setState` 方法来更新状态。

### 4.1 定义状态类

首先，您需要定义一个状态类。强烈建议该类是不可变的，通常通过提供 `copyWith` 方法来实现。

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
import 'my_counter_state.dart'; // 引入状态类

class MyCounterViewModel extends StateViewModel<MyCounterState> {
  // 构造函数中必须通过 super 初始化 state
  MyCounterViewModel({required MyCounterState initialState}) : super(state: initialState);

  void increment() {
    // 使用 setState 更新状态，它会自动处理 notifyListeners
    setState(state.copyWith(count: state.count + 1, statusMessage: "Incremented"));
  }

  void decrement() {
    if (state.count > 0) {
      setState(state.copyWith(count: state.count - 1, statusMessage: "Decremented"));
    } else {
      setState(state.copyWith(statusMessage: "Cannot decrement below zero"));
    }
  }

  void reset() {
    // 可以直接用新的 State 实例替换旧的
    setState(const MyCounterState(count: 0, statusMessage: "Reset"));
  }

  @override
  void dispose() {
    debugPrint('Disposed MyCounterViewModel with state: $state');
    super.dispose();
  }
}
```

在 `StateViewModel` 中，您通过调用 `setState(newState)` 来更新状态。这个方法会用新的状态替换旧的状态，并自动通知所有监听者。

### 4.3 创建 ViewModelFactory

为您的 `StateViewModel` 创建一个对应的 `Factory`。

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
    // 在 build 方法中创建并返回 ViewModel 实例，并传入初始状态
    return MyCounterViewModel(
        initialState: MyCounterState(count: initialCount, statusMessage: "Initialized"));
  }
}
```

### 4.4 在 Widget 中使用有状态 ViewModel

在 `StatefulWidget` 中使用有状态 `ViewModel` 的方式与无状态 `ViewModel` 非常相似，主要区别在于您可以直接访问
`viewModel.state` 来获取当前状态对象。

```dart
// example: lib/my_counter_page.dart
import 'package:flutter/material.dart';
import 'package:view_model/view_model.dart';
import 'my_counter_view_model.dart';
import 'my_counter_view_model_factory.dart';
// MyCounterState 会被 MyCounterViewModel 内部引用

class MyCounterPage extends StatefulWidget {
  const MyCounterPage({super.key});

  @override
  State<MyCounterPage> createState() => _MyCounterPageState();
}

class _MyCounterPageState extends State<MyCounterPage>
    with ViewModelStateMixin<MyCounterPage> {

  MyCounterViewModel get counterVM =>
      watchViewModel<MyCounterViewModel>(
          factory: MyCounterViewModelFactory(initialCount: 10)); // 可以传入初始值

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Stateful ViewModel Counter')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'Count: ${counterVM.state.count}', // 直接访问 state 的属性
              style: Theme
                  .of(context)
                  .textTheme
                  .headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Status: ${counterVM.state.statusMessage}', // 访问 state 的其他属性
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
            tooltip: 'Increment',
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            onPressed: () => counterVM.decrement(),
            tooltip: 'Decrement',
            child: const Icon(Icons.remove),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.extended(
            onPressed: () => counterVM.reset(),
            tooltip: 'Reset',
            icon: const Icon(Icons.refresh),
            label: const Text("Reset"),
          ),
        ],
      ),
    );
  }
}
```

### 4.5 监听状态变化 (`listenState`)

对于 `StateViewModel`，除了通用的 `listen()` 方法外，还有一个专门的 `listenState()`
方法，它允许您在状态对象实际发生变化时接收到旧状态和新状态。

```dart
// 在 State 的 initState 或其他适当方法中
late VoidCallback _disposeStateListener;

@override
void initState() {
  super.initState();

  final myStateVM = watchViewModel<MyCounterViewModel>(factory: MyCounterViewModelFactory());

  _disposeStateListener = myStateVM.listenState(
      onChanged: (MyCounterState? previousState, MyCounterState currentState) {
        print('State changed! Previous count: ${previousState?.count}, New count: ${currentState
            .count}');
        print('Message: ${currentState.statusMessage}');
        // 例如：ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Count is now ${currentState.count}')));
      }
  );
}

@override
void dispose() {
  _disposeStateListener(); // 清理监听器
  super.dispose();
}
```

`listenState` 同样返回一个 `VoidCallback` 用于取消监听，请务必在 `State` 的 `dispose` 方法中调用它。

## 5、其他的进阶用法

### 5.1 全局获取 ViewModel 实例

除了在 StatefulWidget 中使用 watchViewModel() 和 readViewModel()，你还可以在任意位置全局访问已有的
ViewModel 实例，比如在业务逻辑层、路由跳转逻辑、服务模块中。

1. 直接根据类型查找：
    ```dart
    final MyViewModel vm = ViewModel.read<MyViewModel>();
    ```
2. 根据 key 查找：
    ```dart
    final vm = ViewModel.read<MyViewModel>(key: 'user-profile');
    ```

> ⚠️如果找不到指定类型的 ViewModel 实例，将抛出异常。请确保在使用前已正确创建并注册了 ViewModel。

### 5.2 手动管理 ViewModel 生命周期

在某些高级场景下，您可能需要显式地从缓存中移除（并 `dispose`）一个 `ViewModel` 实例。

* **`recycleViewModel<T extends ViewModel>(T viewModel)` (在 `ViewModelStateMixin` 中)**
    * 此方法会立即从内部缓存中移除指定的 `viewModel` 实例，并调用其 `dispose()` 方法。
    * 所有之前 `watch` 或 `read` 该实例的地方，如果再次尝试访问，将会根据其 `Factory` 的配置重新创建或获取。

```dart
MyComplexViewModel get complexViewModel =>
    watchViewModel<MyComplexViewModel>(
        factory: MyComplexViewModelFactory());

void resetAndRefreshTask() {
  final vmToRecycle = complexViewModel;
  recycleViewModel(vmToRecycle);
  // 再次访问 complexViewModel 会得到新实例
  print(complexViewModel.state.status); // 假设是 StateViewModel
  print(complexViewModel.someProperty); // 假设是 ViewModel
}
```

**谨慎使用 `recycleViewModel`**：不当使用可能导致正在使用该 `ViewModel` 的其他 Widget 出现意外行为。

## 6. 关于局部刷新

`view_model` 本身不直接处理 UI 的“局部刷新”的粒度。当 `ViewModel` 调用 `notifyListeners()`
时，所有 `watch` 了该 `ViewModel` 的 `StatefulWidget` 的 `build` 方法都会被调用。Flutter 框架自身会进行高效的
Widget Diffing，仅重新渲染实际改变的部分。

通常情况下，依赖 Flutter 的这种机制已经足够高效。一个组件的 `build` 方法主要负责描述 UI
配置，频繁调用它本身并不会带来显著的性能开销，除非 `build` 方法内部有非常耗时的计算。

如果确实需要更细粒度的控制，可以结合使用 Flutter 内置的 `ValueListenableBuilder`。将 `ViewModel`
中的某个具体值包装在 `ValueNotifier` 中，并在 `ViewModel` 中更新它，然后在 UI 中使用
`ValueListenableBuilder` 监听这个 `ValueNotifier`。

```dart
// 在 ViewModel 中:
class MyFineGrainedViewModel extends ViewModel {
  final ValueNotifier<String> specificData = ValueNotifier("Initial");

  void updateSpecificData(String newData) {
    specificData.value = newData;
    // 如果还需要通知整个 ViewModel 的监听者，也可以额外调用 notifyListeners()
  }
}
```

```dart
// 在 Widget 的 build 方法中:
Widget buildValueListenableBuilder() {
  return ValueListenableBuilder<String>(
    valueListenable: viewModel.specificData, // 假设 viewModel 是 MyFineGrainedViewModel 实例
    builder: (context, value, child) {
      return Text(value); // 这个 Text 只在 specificData 变化时重建
    },
  );
}
```