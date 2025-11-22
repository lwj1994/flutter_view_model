<p align="center">
  <img src="https://youke1.picui.cn/s1/2025/10/17/68f20115693e6.png" alt="ViewModel 标志" height="96" />
</p>

# view_model

> Flutter 中缺失的 ViewModel

[![Pub Version](https://img.shields.io/pub/v/view_model)](https://pub.dev/packages/view_model) [![Codecov (with branch)](https://img.shields.io/codecov/c/github/lwj1994/flutter_view_model/main)](https://app.codecov.io/gh/lwj1994/flutter_view_model/tree/main)

[更新日志](CHANGELOG.md)

[English Doc](README.md) | [中文文档](README_ZH.md)

> 感谢 [Miolin](https://github.com/Miolin) 将
> [view_model](https://pub.dev/packages/view_model) 包的权限转移给我。

---
## 设计理念

**ViewModel 是专门为 UI 逻辑和服务而生的，而不是为了处理复杂的数据流。**

Riverpod 等通用状态管理方案倾向于把所有东西都变成 Provider，而 `view_model` 的定位非常明确：**只做表现层 (Presentation Layer) 该做的事**。

- **为 UI 服务**: 它负责管理 UI 的生命周期（比如页面暂停/恢复时该干嘛）、响应用户的点击操作、把数据转换成 UI 能直接展示的状态。
- **不碰复杂数据**: 那些复杂的数据缓存、拼接、转换逻辑，应该交给下层的 **Repository/Data Layer** 去做（这才是 Riverpod/Signals 发光发热的地方）。
- **兄弟协作**: ViewModel 之间的依赖更多是为了“协同干活”（比如：“用户退出了 -> 购物车 ViewModel 你把东西清一下”），而不是为了“计算数据”。

**一句话总结：用 `view_model` 来构建聪明、懂生命周期的 UI 层，把脏活累活留给数据层。**

---

## 快速开始

- 监听 (Watch): `watchViewModel<T>()` / `watchCachedViewModel<T>()`
- 读取 (Read): `readViewModel<T>()` / `readCachedViewModel<T>()`
- 全局 (Global): `ViewModel.readCached<T>() / maybeReadCached<T>()`
- 回收 (Recycle): `recycleViewModel(vm)`
- 副作用 (Effects): `listen(onChanged)` / `listenState` / `listenStateSelect`
- 依赖 (Dependencies): 在 ViewModel 中使用 `watchCachedViewModel<T>()` / `readCachedViewModel<T>()`

## 复用实例

- Key: 在 factory 中设置 `key()` → 所有 widget 共享同一个实例
- Tag: 设置 `tag()` → 通过 `watchCachedViewModel(tag)` 绑定最新实例
- 任意参数: 传递任意 `Object` 作为 key/tag (例如 `'user:$id'`)

> [!IMPORTANT]
> 当使用自定义对象作为 `key` 或 `tag` 时，请确保正确实现 `==` 运算符和 
> `hashCode` 方法，以保证缓存查找的准确性。可以使用第三方库如 
> [equatable](https://pub.dev/packages/equatable) 或 
> [freezed](https://pub.dev/packages/freezed) 来简化实现。

```dart
final f = DefaultViewModelFactory<UserViewModel>(
  builder: () => UserViewModel(userId: id),
  key: 'user:$id',
);
final vm1 = watchViewModel(factory: f);
final vm2 = watchCachedViewModel<UserViewModel>(key: 'user:$id'); // 相同
```

## 基本用法

### 1. 添加依赖

```yaml
dependencies:
  view_model: <latest_version>
```

### 2. 创建 ViewModel

继承 `ViewModel` 并添加你的业务逻辑。

```dart
class MySimpleViewModel extends ViewModel {
  int _counter = 0;
  int get counter => _counter;

  void incrementCounter() {
    _counter++;
    notifyListeners(); // 通知监听者进行重建
  }
}
```

### 3. 创建 ViewModelFactory

`ViewModelFactory` 负责创建和识别 `ViewModel` 实例。

```dart
class MySimpleViewModelFactory with ViewModelFactory<MySimpleViewModel> {
  @override
  MySimpleViewModel build() => MySimpleViewModel();

  @override
  Object? key() => "MySimpleViewModel"; // 用于共享的唯一键
}
```

### 4. 在 Widget 中使用 ViewModel

在 `StatefulWidget` 中混入 `ViewModelStateMixin` 并使用 `watchViewModel`。

```dart
class MyPage extends StatefulWidget {
  const MyPage({super.key});
  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> with ViewModelStateMixin<MyPage> {
  late final MySimpleViewModel vm = watchViewModel(
    factory: MySimpleViewModelFactory(),
  );

  @override
  Widget build(BuildContext context) {
    return Text(vm.counter.toString());
  }
}
```

### ViewModelBuilder

对于简单场景，`ViewModelBuilder` 可以简化代码。

```dart
ViewModelBuilder<MySimpleViewModel>(
  factory: MySimpleViewModelFactory(),
  builder: (vm) {
    return Text(vm.counter.toString());
  },
);
```

### CachedViewModelBuilder

如果你需要绑定到一个已经存在的 `ViewModel` 实例（例如，在另一个页面创建的），使用 `CachedViewModelBuilder`。

```dart
// 示例：使用 CachedViewModelBuilder 绑定到已存在的实例
CachedViewModelBuilder<MySimpleViewModel>(
  shareKey: "shared-key", // 或 tag: "shared-tag"
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

### 使用监听器处理副作用

```dart
// 在 State 的 initState 或其他合适的方法中
late VoidCallback _disposeViewModelListener;

@override
void initState() {
  super.initState();

  // 获取 ViewModel 实例
  final myVm = watchViewModel<MySimpleViewModel>(factory: MySimpleViewModelFactory());

  _disposeViewModelListener = myVm.listen(onChanged: () {
    print('MySimpleViewModel 调用了 notifyListeners！当前计数：${myVm.counter}');
    // 例如：ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('操作已执行！')));
  });
}

@override
void dispose() {
  _disposeViewModelListener(); // 清理监听器以防内存泄漏
  super.dispose();
}
```

### 可见性 暂停/恢复

[文档](https://github.com/lwj1994/flutter_view_model/blob/main/docs/PAUSE_RESUME_LIFECYCLE.md)

### 暂停/恢复 生命周期

暂停/恢复生命周期由 `ViewModelPauseProvider` 管理。默认情况下，
`PageRoutePauseProvider`、`TickerModePauseProvider` 和 `AppPauseProvider` 分别根据路由可见性和应用生命周期事件处理暂停/恢复。

## 详细参数说明

### ViewModelFactory

Factory 用于创建和识别实例。使用 `key()` 共享一个实例，使用 `tag()` 进行分组/发现。

| 方法/属性 | 类型      | 可选          | 描述                                                                                                                                            |
| --------------- | --------- | ----------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `build()`       | `T`       | ❌ 必须实现 | 创建 ViewModel 实例的工厂方法。通常在这里传递构造函数参数。                                                  |
| `key()`         | `Object?` | ✅ 可选       | 为 ViewModel 提供唯一的标识符。具有相同 key 的 ViewModel 将自动共享（推荐用于跨小部件/页面共享）。 |
| `tag()`      | `Object?` | ✅                | 为 ViewModel 实例添加一个标签。通过 `viewModel.tag` 获取标签。它用于通过 `watchViewModel(tag:tag)` 查找 ViewModel。                            |

> **注意**：如果使用自定义 key 对象，请实现 `==` 和 `hashCode` 以确保正确的缓存查找。

```dart
class MyViewModelFactory with ViewModelFactory<MyViewModel> {
  // 你的自定义参数，通常传递给 MyViewModel
  final String initialName;

  MyViewModelFactory({required this.initialName});

  @override
  MyViewModel build() {
    return MyViewModel(name: initialName);
  }

  /// 用于共享 ViewModel 的 key。key 是唯一的，对于同一个 key 只会创建一个 ViewModel 实例。
  /// 如果 key 为 null，则不会发生共享。
  @override
  Object? key() => "user-profile";
}
```

### ViewModel 生命周期

- `watch*` / `read*` 将 ViewModel 绑定到一个 State
- 当没有小部件观察者时，实例会自动销毁

### ViewModel → ViewModel 依赖

在 ViewModel 内部，使用 `readCachedViewModel`（非反应式）或 `watchCachedViewModel`（反应式）来访问其他 ViewModel。

**核心概念**：虽然看起来 ViewModel 之间是互相依赖，但实际上它们都挂靠到**同一个 Widget 的 State**。依赖结构是**平层的**（只有 1 层深度）—— 所有 ViewModel 都由同一个 `State` 对象管理。ViewModel 之间只存在**监听关系**，而非嵌套依赖。

- **生命周期**：当 `HostVM` 通过 `watchCachedViewModel` 访问 `SubVM` 时，两者都挂靠到同一个 Widget `State`。
- **清理机制**：当 `State` 被销毁时，所有挂靠的 ViewModel 会一起被销毁（如果没有其他 Widget 监听它们）。
- **协作方式**：ViewModel 之间通过监听来协调动作，保持在同一个 UI 层。

```dart
class UserProfileViewModel extends ViewModel {
  void loadData() {
    // 一次性访问，不监听
    final authVM = readCachedViewModel<AuthViewModel>();
    if (authVM?.isLoggedIn == true) {
      _fetchProfile(authVM!.userId);
    }
  }

  void setupReactiveAuth() {
    // 反应式访问 - 当 auth 发生变化时自动更新
    final authVM = watchCachedViewModel<AuthViewModel>();
    // 当 authVM 发生变化时，此 ViewModel 将收到通知
  }

  void manualListening() {
    final authVM = readCachedViewModel<AuthViewModel>();
    // 你也可以手动监听任何 ViewModel
    authVM?.listen(() {
      // 自定义监听逻辑
      _handleAuthChange(authVM);
    });
  }
}
```

## 有状态的 ViewModel (`StateViewModel<S>`)

当你更喜欢使用不可变的 `state` 对象并通过 `setState(newState)` 进行更新时，请使用 `StateViewModel<S>`。支持 `listenState(prev, next)` 以进行特定于状态的反应。

> [!NOTE]
> 默认情况下，`StateViewModel` 使用 `identical()` 来比较 state 实例（比较对象引用，
> 而非内容）。这意味着只有当你提供一个新的 state 实例时，`setState()` 才会触发重建。
> 你可以通过在 `ViewModel.initialize()` 中配置 `equals` 函数来全局自定义这种比较
> 行为（参见[初始化](#初始化)部分）。

### 定义 State 类

首先，你需要定义一个 state 类。强烈建议该类是不可变的，通常通过提供 `copyWith` 方法来实现。

```dart
// 示例: lib/my_counter_state.dart
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

### 创建有状态的 ViewModel

继承自 `StateViewModel<S>`，其中 `S` 是你定义的 state 类的类型。

```dart
// 示例: lib/my_counter_view_model.dart
import 'package:view_model/view_model.dart';
import 'package:flutter/foundation.dart';
import 'my_counter_state.dart'; // 导入 state 类

class MyCounterViewModel extends StateViewModel<MyCounterState> {
  // 构造函数必须通过 super 初始化 state
  MyCounterViewModel({required MyCounterState initialState}) : super(state: initialState);

  void increment() {

              // 使用 copyWith 更新状态
    setState(state.copyWith(count: state.count + 1));
  }

  void updateStatus(String newStatus) {
    // 或者创建一个全新的状态实例
    setState(MyCounterState(count: state.count, statusMessage: newStatus));
  }

  @override
  void onStateChanged(MyCounterState previousState, MyCounterState currentState) {
    // 可选：监听状态变化
    if (previousState.count != currentState.count) {
      print('Counter changed: ${currentState.count}');
    }
  }
}
```

### 为有状态的 ViewModel 创建 ViewModelFactory

```dart
// 示例: lib/my_counter_view_model_factory.dart
import 'package:view_model/view_model.dart';
import 'my_counter_view_model.dart';
import 'my_counter_state.dart';

class MyCounterViewModelFactory with ViewModelFactory<MyCounterViewModel> {
  @override
  MyCounterViewModel build() {
    // 提供初始状态
    return MyCounterViewModel(initialState: const MyCounterState());
  }

  @override
  Object? key() => MyCounterViewModel;
}
```

### 在小部件中使用有状态的 ViewModel

使用 `ViewModelBuilder` 或 `ViewModelStateMixin` 来监听 state 的变化并自动重建你的 UI。

```dart
// 示例: lib/my_counter_page.dart
import 'package:flutter/material.dart';
import 'package:view_model/view_model.dart';
import 'my_counter_view_model.dart';
import 'my_counter_view_model_factory.dart';

class MyCounterPage extends StatelessWidget {
  const MyCounterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder<MyCounterViewModel>(
      factory: MyCounterViewModelFactory(),
      builder: (context, viewModel) {
        return Scaffold(
          appBar: AppBar(title: const Text('有状态的 ViewModel 示例')),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  '状态: ${viewModel.state.statusMessage}', // 从 state 读取
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  '${viewModel.state.count}', // 从 state 读取
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => viewModel.increment(), // 调用方法来更新 state
            tooltip: 'Increment',
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }
}
```

### 默认 ViewModelFactory

如果你不想为每个 ViewModel 创建一个工厂类，可以使用 `DefaultViewModelFactory`。它通过反射来创建 ViewModel 实例，但有一些限制：

- ViewModel 必须有一个无参数的构造函数。
- 它不支持传递构造函数参数。

```dart
// 直接在小部件中使用
final myVM = watchViewModel<MyViewModel>(
  factory: DefaultViewModelFactory<MyViewModel>(),
);
```

## 初始化

在使用任何 `view_model` 功能之前，你必须在你的 `main` 函数中调用 `ViewModel.initialize`。这对于配置全局行为（如日志记录和生命周期管理）至关重要。

```dart
// 示例: lib/main.dart
import 'package:flutter/material.dart';
import 'package:view_model/view_model.dart';

void main() {
  // 在 runApp 之前初始化
  ViewModel.initialize(
    // 配置选项
    config: ViewModelConfig(
      // (可选) 启用或禁用日志记录
      isLoggingEnabled: true,

      // (可选) 提供一个自定义的相等比较函数
      // 默认使用 `==`
      equals: (previous, next) {
        // 例如，与 equatable 集成
        if (previous is Equatable && next is Equatable) {
          return previous == next;
        }
        return previous == next;
      },

      // (可选) 注册全局生命周期监听器
      lifecycles: [
        GlobalViewModelLifecycle(),
      ],
    ),
  );

  runApp(const MyApp());
}
```

### 配置选项

- `isLoggingEnabled`: (`bool`) 切换 `ViewModel` 活动的日志记录。
- `equals`: (`Equals`) 一个函数，用于确定状态何时被视为“已更改”。
- `lifecycles`: (`List<ViewModelLifecycle>`) 全局生命周期监听器列表。

## 生命周期

`ViewModel` 提供了生命周期回调，允许你在创建、初始化和销毁等不同阶段执行代码。这对于管理资源、执行一次性逻辑或日志记录非常有用。

### 单个 ViewModel 的生命周期

要为单个 `ViewModel` 实现生命周期回调，请使用 `ViewModelLifecycle` mixin。

- `onCreate()`: 在 `ViewModel` 第一次创建时调用。这是设置初始状态或资源的理想位置。
- `onInit()`: 在 `ViewModel` 第一次被监听时调用。适用于需要响应 UI 交互的逻辑。
- `onDispose()`: 在 `ViewModel` 被销毁时调用。用于清理资源，如关闭流或取消订阅。

```dart
class MyLifecycleViewModel extends ViewModel with ViewModelLifecycle {
  @override
  void onCreate() {
    print("MyLifecycleViewModel: onCreate");
    // 在此设置资源
  }

  @override
  void onInit() {
    print("MyLifecycleViewModel: onInit");
    // UI 准备好后执行
  }

  @override
  void onDispose() {
    print("MyLifecycleViewModel: onDispose");
    // 在此清理资源
  }
}
```

### 全局 ViewModel 生命周期

如果你想监听应用程序中所有 `ViewModel` 的生命周期事件，可以注册一个全局生命周期观察者。

1.  **创建一个全局生命周期类**

    实现 `ViewModelLifecycle` 接口。

    ```dart
    class GlobalViewModelLifecycle with ViewModelLifecycle {
      @override
      void onCreate(ViewModel viewModel) {
        print("Global: ${viewModel.runtimeType} created");
      }

      @override
      void onInit(ViewModel viewModel) {
        print("Global: ${viewModel.runtimeType} initialized");
      }

      @override
      void onDispose(ViewModel viewModel) {
        print("Global: ${viewModel.runtimeType} disposed");
      }
    }
    ```

2.  **在初始化期间注册它**

    将你的全局监听器添加到 `ViewModel.initialize` 的 `lifecycles` 列表中。

    ```dart
    void main() {
      ViewModel.initialize(
        config: ViewModelConfig(
          lifecycles: [GlobalViewModelLifecycle()],
        ),
      );
## 值级别重建

### StateViewModelValueWatcher

对于 `StateViewModel`，你可以使用 `StateViewModelValueWatcher` 来监听 `state` 中特定属性的变化。它需要一个 `selector` 函数来提取要观察的值。

```dart
// 假设 MyCounterState 有一个 'count' 属性

StateViewModelValueWatcher<MyCounterViewModel, int>(
  viewModel: counterVM, // 你的 StateViewModel 实例
  selector: (state) => state.count, // 选择要观察的属性
  builder: (context, count) {
    // 当 'count' 变化时，这个 Text 小部件会重建
    return Text("Count: $count");
  },
);
```

### ValueNotifier 和 ObservableValue

- **`ValueNotifier<T>`**: Flutter SDK 中的一个类，持有一个值并在值发生变化时通知其监听者。
- **`ObservableValue<T>`**: `view_model` 中的一个 `ValueNotifier` 包装器，它会自动在 `ViewModel` 销毁时被释放。

```dart
class MyViewModel extends ViewModel {
  // 使用 ObservableValue 来包装你的可观察属性
  final ObservableValue<int> counter = ObservableValue(0);
  final ObservableValue<String> userName = ObservableValue("Guest");

  void increment() {
    counter.value++; // 只会重建监听 counter 的小部件
  }

  void setUserName(String name) {
    userName.value = name; // 只会重建监听 userName 的小部件
  }
}
```

### ObserverBuilder

`ObserverBuilder` 是一个专门用于监听 `ValueNotifier` 的小部件。当 `ValueNotifier` 的值发生变化时，它会自动重建其 `builder` 中的内容。

```dart
class MyPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final myVM = watchViewModel<MyViewModel>(factory: MyViewModelFactory());

    return Column(
      children: [
        // 这个 ObserverBuilder 只监听 counter
        ObserverBuilder(
          observable: myVM.counter,
          builder: (context, count) {
            print("Counter rebuilt");
            return Text("Counter: $count");
          },
        ),
        // 这个 ObserverBuilder 只监听 userName
        ObserverBuilder(
          observable: myVM.userName,
          builder: (context, name) {
            print("UserName rebuilt");
            return Text("User: $name");
          },
        ),
        ElevatedButton(
          onPressed: () => myVM.increment(),
          child: Text("Increment"),
        ),
      ],
    );
  }
}
```


## DevTools 扩展

`view_model` 包带有一个 DevTools 扩展，可以帮助你：

- **可视化 ViewModel 实例**：查看所有活动的 ViewModel、它们的类型和当前的观察者数量。
- **检查 ViewModel 状态**：检查 `StateViewModel` 的当前状态或 `ViewModel` 的属性。
- **跟踪生命周期事件**：监控 `onCreate`、`onInit` 和 `onDispose` 事件。

### 如何使用

1.  **运行你的 Flutter 应用**：确保你的应用正在运行。
2.  **打开 DevTools**：从你的 IDE 或命令行启动 DevTools。
3.  **选择 `view_model` 标签**：在 DevTools 标签页中找到并点击 `view_model`。

![DevTools 截图](https://raw.githubusercontent.com/ditclear/flutter_view_model/master/packages/view_model/screenshots/devtools.png)

## 值级别重建

为了实现更精细的 UI 更新，你可以使用 `ValueNotifier` 配合 `ValueListenableBuilder`。

```dart
final title = ValueNotifier('Hello');
ValueListenableBuilder(
  valueListenable: title,
  builder: (_, v, __) => Text(v),
);
```

对于更动态的场景，`ObservableValue` 和 `ObserverBuilder` 提供了更大的灵活性。

```dart
// shareKey 用于在任何小部件之间共享值
final observable = ObservableValue<int>(0, shareKey: share);
observable.value = 20;

ObserverBuilder<int>(observable: observable, 
        builder: (v) {
          return Text(v.toString());
        },
      )
```

如果只想在 `StateViewModel` 中的特定值发生变化时才重建，请使用 `StateViewModelValueWatcher`。

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
    // 监听 stateViewModel 上的值变化，并且仅当 name 或 age 变化时才重建。
    return StateViewModelValueWatcher<MyViewModel>(
      stateViewModel: stateViewModel,
      selectors: [(state) => state.name, (state) => state.age],
      builder: (state) {
        return Text('Name: ${state.name}, Age: ${state.age}');
      },
    );
  }
}
```

## DevTools 扩展

启用 DevTools 扩展以进行实时 ViewModel 监控。

在你的项目根目录中创建 `devtools_options.yaml` 文件。

```yaml
description: This file stores settings for Dart & Flutter DevTools.
documentation: https://docs.flutter.dev/tools/devtools/extensions#configure-extension-enablement-states
extensions:
  - view_model: true
```

![](https://i.imgur.com/5itXPYD.png)
![](https://imgur.com/83iOQhy.png)


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
