# view_model

轻量级的 Flutter 状态管理库，让状态管理变得简单。

| 包名 | 版本 |
| :--- | :--- |
| **view_model** | [![Pub Version](https://img.shields.io/pub/v/view_model)](https://pub.dev/packages/view_model) |
| **view_model_annotation** | [![Pub Version](https://img.shields.io/pub/v/view_model_annotation)](https://pub.dev/packages/view_model_annotation) |
| **view_model_generator** | [![Pub Version](https://img.shields.io/pub/v/view_model_generator)](https://pub.dev/packages/view_model_generator) |

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

[English](README.md) | 简体中文

## 为什么选择 view_model？

- **零样板代码** - 只需添加一个 mixin，无需根节点包装或复杂配置
- **自动生命周期** - Widget 销毁时自动回收，防止内存泄漏
- **智能省电** - 后台或隐藏页面自动暂停更新，节省性能
- **细粒度更新** - 支持字段级响应式，只重建必要的部分
- **依赖管理** - ViewModel 之间可以直接访问和监听

## 快速开始

### 安装

```yaml
dependencies:
  view_model: ^0.14.2
```

### 三步上手

#### 1. 定义状态类

```dart
class CounterState {
  final int count;

  const CounterState({this.count = 0});

  CounterState copyWith({int? count}) {
    return CounterState(count: count ?? this.count);
  }
}
```

#### 2. 创建 ViewModel

```dart
import 'package:view_model/view_model.dart';

// 定义 Spec（全局单例）
final counterSpec = ViewModelSpec<CounterViewModel>(
  key: 'counter',  // 使用 key 共享实例
  builder: () => CounterViewModel(),
);

// 创建 ViewModel
class CounterViewModel extends StateViewModel<CounterState> {
  CounterViewModel() : super(state: const CounterState());

  void increment() {
    setState(state.copyWith(count: state.count + 1));
  }

  void decrement() {
    setState(state.copyWith(count: state.count - 1));
  }
}
```

#### 3. 在 Widget 中使用

```dart
class CounterPage extends StatefulWidget {
  const CounterPage({super.key});

  @override
  State<CounterPage> createState() => _CounterPageState();
}

// 添加 ViewModelStateMixin
class _CounterPageState extends State<CounterPage>
    with ViewModelStateMixin<CounterPage> {

  @override
  Widget build(BuildContext context) {
    // 使用 viewModelBinding.watch 监听 ViewModel
    final counter = viewModelBinding.watch(counterSpec);

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Count: ${counter.state.count}',
              style: const TextStyle(fontSize: 48)),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: counter.decrement,  // 使用 read，不监听
                  child: const Text('-'),
                ),
                const SizedBox(width: 20),
                ElevatedButton(
                  onPressed: counter.increment,
                  child: const Text('+'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
```

### 初始化（可选）

```dart
void main() {
  ViewModel.initialize(
    config: ViewModelConfig(
      isLoggingEnabled: true,  // 开启日志
    ),
  );
  runApp(const MyApp());
}
```

## 核心概念

### ViewModelBinding - ViewModel 执行框架

ViewModelBinding 提供四个核心方法来访问 ViewModel：

| 方法 | 使用场景 | 效果 |
|------|---------|------|
| `viewModelBinding.watch(provider)` | 在 build 方法中 | 监听变化并重建 Widget |
| `viewModelBinding.read(provider)` | 在事件回调中 | 读取数据但不监听 |
| `viewModelBinding.watchCached({key})` | 访问已存在的实例 | 监听缓存的 ViewModel |
| `viewModelBinding.readCached({key})` | 读取已存在的实例 | 不监听缓存的 ViewModel |

```dart
// 示例：watch vs read
@override
Widget build(BuildContext context) {
  final vm = viewModelBinding.watch(provider);  // ✅ 在 build 中使用 watch
  return ElevatedButton(
    onPressed: () {
      final vm = viewModelBinding.read(provider);  // ✅ 在回调中使用 read
      vm.doSomething();
    },
    child: Text(vm.state.title),
  );
}
```

### 实例共享和生命周期

#### 1. 自动回收（默认）

不使用 `key` 时，每个 Widget 持有独立实例，Widget 销毁时自动回收：

```dart
final provider = ViewModelSpec<MyViewModel>(
  builder: () => MyViewModel(),
  // 无 key，自动回收
);
```

#### 2. 共享实例

使用 `key` 时，相同 key 的 Widget 共享同一个实例，所有 Widget 都销毁后才回收：

```dart
final userSpec = ViewModelSpec<UserViewModel>(
  key: 'current-user',  // 所有使用此 key 的 Widget 共享实例
  builder: () => UserViewModel(),
);
```

#### 3. 永久保活

使用 `aliveForever: true` 时，实例永不销毁：

```dart
final configSpec = ViewModelSpec<ConfigViewModel>(
  key: 'app-config',
  aliveForever: true,  // 永久保活
  builder: () => ConfigViewModel(),
);
```

### 智能暂停机制

ViewModel 内置三种自动暂停机制，节省性能：

1. **应用后台暂停** - App 进入后台时自动暂停
2. **路由覆盖暂停** - 页面被其他路由覆盖时暂停
3. **TabBar 暂停** - TabBarView 中不可见的 Tab 暂停

暂停后的更新会被队列化，恢复时一次性重建，避免无效计算。

#### 启用路由暂停

```dart
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorObservers: [ViewModel.routeObserver],  // 添加路由观察器
      home: HomePage(),
    );
  }
}
```

### 参数化 Spec

支持根据参数创建和复用实例：

```dart
// 定义带参数的 Spec
final userSpec = ViewModelSpec.arg<UserViewModel, int>(
  builder: (userId) => UserViewModel(userId),
  key: (userId) => 'user_$userId',  // 不同参数使用不同 key
);

// 使用
Widget build(BuildContext context) {
  final user1 = viewModelBinding.watch(userSpec(42));   // 创建 user_42
  final user2 = viewModelBinding.watch(userSpec(100));  // 创建 user_100
  final user3 = viewModelBinding.watch(userSpec(42));   // 复用 user_42
}
```

支持 1-4 个参数：`arg`、`arg2`、`arg3`、`arg4`

### ViewModel 之间的依赖

ViewModel 可以直接访问其他 ViewModel：

```dart
final authSpec = ViewModelSpec<AuthViewModel>(
  builder: () => AuthViewModel(),
);

class UserProfileViewModel extends StateViewModel<UserState> {

  void loadProfile() {
    // 读取认证 ViewModel
    final auth = viewModelBinding.read(authSpec);

    if (auth.isLoggedIn) {
      // 加载用户数据...
    }
  }

  // 监听其他 ViewModel 的变化
  @override
  void onCreate(InstanceArg arg) {
    super.onCreate(arg);

    listenState(authSpec, (previous, next) {
      if (next.isLoggedOut) {
        // 清空用户数据
        setState(const UserState());
      }
    });
  }
}
```

### 细粒度响应式

#### 1. ValueWatcher - 字段级重建

只监听状态中的特定字段，减少不必要的重建：

```dart
StateViewModelValueWatcher<UserViewModel, UserState>(
  stateViewModel: userViewModel,
  selectors: [
    (state) => state.name,  // 只监听 name 字段
    (state) => state.age,   // 只监听 age 字段
  ],
  builder: (state) => Text('${state.name}, ${state.age}'),
)
```

#### 2. ObservableValue - 独立响应式值

创建独立的响应式值，不依赖 ViewModel：

```dart
// 创建共享的响应式值
final counter = ObservableValue<int>(0, shareKey: 'counter');

// 在任何地方修改
counter.value = 42;

// 在 Widget 中监听
ObserverBuilder<int>(
  observable: counter,
  builder: (value) => Text('$value'),
)
```

### 生命周期钩子

```dart
class MyViewModel extends StateViewModel<MyState> {
  @override
  void onCreate(InstanceArg arg) {
    super.onCreate(arg);
    // 初始化资源
    print('ViewModel 创建');
  }

  @override
  void onBindVef(InstanceArg arg, String vefId) {
    super.onBindVef(arg, vefId);
    // 有新的 Widget 开始监听
    print('Widget 绑定');
  }

  @override
  void onUnbindVef(InstanceArg arg, String vefId) {
    super.onUnbindVef(arg, vefId);
    // Widget 停止监听
    print('Widget 解绑');
  }

  @override
  void onDispose(InstanceArg arg) {
    // 清理资源
    print('ViewModel 销毁');
    super.onDispose(arg);
  }
}
```

## 代码生成

使用 `@GenProvider` 注解自动生成 Spec：

### 1. 添加依赖

```yaml
dependencies:
  view_model: ^0.14.2
  view_model_annotation: ^0.14.2

dev_dependencies:
  view_model_generator: ^0.14.2
  build_runner: ^2.4.0
```

### 2. 使用注解

```dart
import 'package:view_model_annotation/view_model_annotation.dart';

part 'user_view_model.vm.dart';  // 生成的文件

@GenProvider(
  key: Expression('user_\$userId'),  // 支持字符串插值
  aliveForever: false,
)
class UserViewModel extends StateViewModel<UserState> {
  factory UserViewModel.provider(int userId) => UserViewModel(userId);

  UserViewModel(this.userId) : super(state: UserState());

  final int userId;
}
```

### 3. 运行生成

```bash
dart run build_runner build
```

生成的代码：

```dart
// user_view_model.vm.dart
final userSpec = ViewModelSpec.arg<UserViewModel, int>(
  builder: (userId) => UserViewModel(userId),
  key: (userId) => 'user_$userId',
);
```

## 进阶功能

### 在普通 Dart 类中使用

不仅限于 Widget，任何 Dart 类都可以使用：

```dart
class StartupTask with ViewModelBinding {
  Future<void> run() async {
    final config = read(configSpec);
    await config.initialize();

    final auth = read(authSpec);
    await auth.checkLogin();
  }
}

final configSpec = ViewModelSpec<ConfigViewModel>(
  builder: () => ConfigViewModel(),
);

final authSpec = ViewModelSpec<AuthViewModel>(
  builder: () => AuthViewModel(),
);

// 在 main 中使用
void main() {
  ViewModel.initialize();
  StartupTask().run();
  runApp(MyApp());
}
```

### Repository 作为 ViewModel

```dart
class UserRepository with ViewModel {

  Future<User> fetchUser(int id) async {
    // 可以访问其他 ViewModel
    final token = read(authSpec).token;
    return await api.getUser(id, token);
  }
}

final userRepoSpec = ViewModelSpec<UserRepository>(
  builder: () => UserRepository(),
);
```

### 全局生命周期监听

```dart
void main() {
  ViewModel.addLifecycle(MyObserver());
  runApp(MyApp());
}

class MyObserver implements ViewModelLifecycle {
  @override
  void onCreate<T extends ViewModel>(T vm, InstanceArg arg) {
    print('Created: ${vm.runtimeType}');
  }

  @override
  void onDispose<T extends ViewModel>(T vm, InstanceArg arg) {
    print('Disposed: ${vm.runtimeType}');
  }
}
```

## 完整示例

查看 [example](../../example) 目录：

- [counter](../../example/counter) - 简单计数器，展示基本用法
- [todo_list](../../example/todo_list) - TODO 应用，展示复杂状态管理

## 文档

- [架构指南](ARCHITECTURE_GUIDE.md)
- [暂停和恢复机制](../../docs/PAUSE_RESUME_LIFECYCLE.md)
- [ValueObserver 文档](../../docs/value_observer_doc.md)
- [代码生成指南](../../docs/build_runner.md)

## 许可证

MIT License - 详见 [LICENSE](../../LICENSE) 文件

## 贡献

欢迎提交 Issue 和 Pull Request！

问题反馈：https://github.com/lwj1994/flutter_view_model/issues
