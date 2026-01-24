<p align="center">
  <img src="https://lwjlol-images.oss-cn-beijing.aliyuncs.com/logo.png" alt="ViewModel Logo" height="96" />
</p>

# view_model：Flutter 原生风格状态管理

专为 Flutter 组件架构打造的全面状态管理方案。结合 MVVM 模式、自动生命周期管理、智能性能优化和零样板代码。

**核心亮点：**
- **Flutter 优先设计**：为 Flutter 的 OOP 和组件树架构量身定制
- **极简样板代码**：只需添加一个 mixin - 无需根组件包裹或强制继承
- **自动生命周期**：基于组件生命周期的引用计数和自动销毁
- **智能性能**：暂停机制在组件不可见时延迟更新
- **ViewModel 依赖**：ViewModel 可以直接访问和监听其他 ViewModel
- **细粒度更新**：字段级响应式，只重建变化的部分

| Package | Version |
| :--- | :--- |
| **view_model** | [![Pub Version](https://img.shields.io/pub/v/view_model)](https://img.shields.io/pub/v/view_model) |
| **view_model_annotation** | [![Pub Version](https://img.shields.io/pub/v/view_model_annotation)](https://img.shields.io/pub/v/view_model_annotation) |
| **view_model_generator** | [![Pub Version](https://img.shields.io/pub/v/view_model_generator)](https://img.shields.io/pub/v/view_model_generator) |

[![Codecov](https://img.shields.io/codecov/c/github/lwj1994/flutter_view_model/main)](https://app.codecov.io/gh/lwj1994/flutter_view_model/tree/main)

[更新日志](https://github.com/lwj1994/flutter_view_model/blob/main/packages/view_model/CHANGELOG.md) | [English Doc](README.md) | [架构指南](ARCHITECTURE_GUIDE_ZH.md)

---

## Agent Skills
AI Agent 使用指南请参考 [Agent Skills](https://github.com/lwj1994/flutter_view_model/blob/main/skills/view_model/SKILL.md)。

## 为什么选择 view_model？

本库由习惯 MVVM 架构的移动开发团队（Android、iOS、Flutter）开发，专门为 Flutter 的 OOP 和组件化架构提供原生的 ViewModel 实现。

---

## 安装

```yaml
dependencies:
  view_model: ^latest_version

dev_dependencies:
  build_runner: ^latest_version
  view_model_generator: ^latest_version
```

---

## 快速上手

### 1. 定义 ViewModel
使用 `ViewModel` mixin 或继承 `StateViewModel<T>` 进行不可变状态管理。

**方式 A：简单 ViewModel**
```dart
class CounterViewModel with ViewModel {
  int count = 0;

  void increment() {
    update(() => count++); // 通知监听者
  }
}
```

**方式 B：StateViewModel（推荐）**
```dart
class CounterViewModel extends StateViewModel<CounterState> {
  CounterViewModel() : super(state: const CounterState(count: 0));

  void increment() {
    setState(state.copyWith(count: state.count + 1));
  }
}
```

### 2. 注册 Provider
```dart
final counterProvider = ViewModelProvider<CounterViewModel>(
  builder: () => CounterViewModel(),
  key: "shared-counter", // 可选：跨组件共享实例
  aliveForever: false,   // 可选：即使没有监听者也保持存活
);
```
*提示：使用 `view_model_generator` 配合 `@GenProvider` 注解可自动生成 provider。*

### 3. 在 Widget 中使用
给 State 类添加 `ViewModelStateMixin` 即可访问 `vef` API。对于 StatelessWidget，使用 `ViewModelStatelessMixin`（但推荐使用 StatefulWidget）。

```dart
class _CounterPageState extends State<CounterPage> with ViewModelStateMixin {
  @override
  Widget build(BuildContext context) {
    // watch() 自动监听变化并重建
    final vm = vef.watch(counterProvider);

    return Scaffold(
      body: Center(child: Text('${vm.count}')),
      floatingActionButton: FloatingActionButton(
        // read() 用于回调中的一次性访问
        onPressed: () => vef.read(counterProvider).increment(),
        child: Icon(Icons.add),
      ),
    );
  }
}
```

**备选方案：使用 ViewModelBuilder Widget**
```dart
class CounterPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder<CounterViewModel>(
      provider: counterProvider,
      builder: (vm) => Text('${vm.count}'),
    );
  }
}
```

### 方案对比

| 方案 | 修改点 | 根组件包裹 | BuildContext 依赖 |
|------|-----------|-----------|-----------------|
| **view_model** | 添加 mixin | 不需要 | 不需要 |
| Provider | InheritedWidget | 需要 | 需要 |
| Riverpod | ConsumerWidget | 需要 | 不需要 |
| GetX | 全局状态 | 不需要 | 不需要 |

---

## 核心功能

### 1. 统一访问入口 (Vef)
`Vef` (ViewModel Execution Framework) 在 Widget、ViewModel 和纯 Dart 类中提供了一致的 API 来访问 ViewModel。

| 方法 | 行为 | 适用场景 |
| :--- | :--- | :--- |
| `vef.watch` | 响应式 | `build()` 内部，触发重建 |
| `vef.read` | 直接访问 | 回调、事件处理 |
| `vef.listen` | 副作用监听 | 导航、通知 |
| `vef.listenState` | 状态监听 | 监控状态切换 |

#### 使用示例
- **Widget**: 使用 `ViewModelStateMixin`
- **ViewModel**: 内置 `vef` 访问其他 ViewModel
- **普通类**: 使用 `with Vef`

```dart
class TaskRunner with Vef {
  void run() {
    final authVM = vef.read(authProvider);
    authVM.checkAuth();
  }
}
```

### 2. 暂停机制
为节省资源，`view_model` 在组件不可见时（如被其他路由遮挡、应用切后台、TabBar 中隐藏）自动延迟 UI 更新。

**三个内置暂停提供器：**
- **AppPauseProvider**：应用切后台时暂停（`AppLifecycleState.hidden`）
- **PageRoutePauseProvider**：路由被其他路由遮挡时暂停（使用 `RouteAware`）
- **TickerModePauseProvider**：`TabBarView` 中标签不可见时暂停

**设置（路由感知暂停必需）：**
```dart
MaterialApp(
  navigatorObservers: [ViewModel.routeObserver], // 启用路由感知暂停
  // ...
)
```

**工作原理：**
- `ViewModelStateMixin` 自动集成所有三个提供器
- 当任何提供器发出暂停信号时，ViewModel 的通知会被加入队列
- 组件重新可见时，只触发**单次重建**
- 避免浪费 CPU 周期重建不可见的组件

**自定义暂停控制：**
```dart
class _MyPageState extends State<MyPage> with ViewModelStateMixin {
  final _customPause = ManualVefPauseProvider();

  @override
  void initState() {
    super.initState();
    addPauseProvider(_customPause); // 添加自定义暂停逻辑
  }

  void onSomeEvent() {
    _customPause.pause(); // 手动暂停更新
  }

  void onOtherEvent() {
    _customPause.resume(); // 手动恢复更新
  }
}
```

---

### 3. 细粒度响应
通过只重建必要的部分来优化性能。

**StateViewModelValueWatcher：字段级重建**
```dart
class _UserPageState extends State<UserPage> with ViewModelStateMixin {
  @override
  Widget build(BuildContext context) {
    final vm = vef.read(userProvider); // 读取而不监听整个 VM

    return Column(
      children: [
        // 只在 'name' 或 'age' 变化时重建
        StateViewModelValueWatcher<UserViewModel, UserState>(
          stateViewModel: vm,
          selectors: [(state) => state.name, (state) => state.age],
          builder: (state) => Text('${state.name}, ${state.age}'),
        ),

        // 此组件不会在 name/age 变化时重建
        Text('Email: ${vm.state.email}'),
      ],
    );
  }
}
```

**ObservableValue：独立响应式值**
```dart
// 创建可观察值（可通过 shareKey 共享）
final counter = ObservableValue<int>(0, shareKey: 'shared-counter');

// 更新值
counter.value = 42;

// 在组件中使用
ObserverBuilder<int>(
  observable: counter,
  builder: (value) => Text('$value'),
);

// 观察多个值
ObserverBuilder2<int, String>(
  observable1: counter,
  observable2: username,
  builder: (count, name) => Text('$name: $count'),
);
```

**StateViewModel 监听器：响应式依赖**
```dart
class MyViewModel extends StateViewModel<MyState> {
  @override
  void onCreate(InstanceArg arg) {
    super.onCreate(arg);

    // 监听整个状态变化
    listenState(onChanged: (prev, curr) {
      print('State changed from $prev to $curr');
    });

    // 监听特定字段变化
    listenStateSelect<int>(
      selector: (state) => state.counter,
      onChanged: (prevValue, currValue) {
        if (currValue > 10) {
          // 触发副作用
        }
      },
    );
  }
}
```

| 方式 | 范围 | 适用场景 |
|----------|--------------|----------|
| `vef.watch` | 整个组件 | 简单场景 |
| `StateViewModelValueWatcher` | 选定字段 | 复杂状态 |
| `ObservableValue` + `ObserverBuilder` | 单个值 | 隔离逻辑 |
| `listenStateSelect` | 副作用 | 导航、分析 |

---

### 4. 依赖注入与实例共享
使用明确的参数系统进行依赖注入，并支持跨组件的实例共享。

**基本实例共享：**
```dart
final userProvider = ViewModelProvider<UserViewModel>(
  builder: () => UserViewModel(),
  key: 'current-user', // 相同 key = 跨组件共享相同实例
);
```

**基于参数的 Provider（最多 4 个参数）：**
```dart
// 单个参数
final userProvider = ViewModelProvider.arg<UserViewModel, int>(
  builder: (userId) => UserViewModel(userId),
  key: (userId) => 'user_$userId', // 不同用户使用不同 key
  tag: (userId) => 'user-data',     // 逻辑分组
);

// 使用 - 每个 ID 获得自己的缓存实例
final user1 = vef.watch(userProvider(42));
final user2 = vef.watch(userProvider(100));
final user3 = vef.watch(userProvider(42)); // 复用与 user1 相同的实例

// 两个参数
final productProvider = ViewModelProvider.arg2<ProductViewModel, int, String>(
  builder: (id, category) => ProductViewModel(id, category),
  key: (id, category) => 'product_${id}_$category',
);

// 使用
final vm = vef.watch(productProvider(123, 'electronics'));
```

**查找共享实例：**
```dart
// 通过 key 读取缓存实例
final user = vef.readCached<UserViewModel>(key: 'user_42');

// 监听缓存实例（变化时重建）
final user = vef.watchCached<UserViewModel>(key: 'user_42');

// 查找所有相同 tag 的实例
final allUsers = vef.readCachesByTag<UserViewModel>(tag: 'user-data');

// 安全访问（未找到返回 null）
final user = vef.maybeReadCached<UserViewModel>(key: 'user_42');
```

**ViewModel 之间的依赖：**
```dart
class UserProfileViewModel extends StateViewModel<UserState> {
  void loadProfile() {
    // 无需显式注入即可访问 AuthViewModel
    final auth = vef.read(authProvider);

    if (auth.isLoggedIn) {
      final userId = auth.userId;
      // 加载个人资料数据
    }
  }

  void setupReactiveAuth() {
    // 监听另一个 ViewModel - auth 变化时自动更新
    final auth = vef.watch(authProvider);

    // 监听特定状态变化
    auth.listenState(onChanged: (prev, curr) {
      if (!curr.isLoggedIn && prev.isLoggedIn) {
        // 处理登出
      }
    });
  }
}
```

**代码生成（推荐）：**
```dart
import 'package:view_model_annotation/view_model_annotation.dart';

part 'user_view_model.vm.dart';

@GenProvider(
  key: Expression('userId_\$id'), // key 中的字符串插值
  tag: 'user-data',
  aliveForever: false,
)
class UserViewModel extends StateViewModel<UserState> {
  factory UserViewModel.provider(int id) => UserViewModel(id);

  UserViewModel(this.userId) : super(state: UserState());

  final int userId;
}

// 运行：dart run build_runner build
// 生成：带有正确参数处理的 userProvider
```

---

### 5. 生命周期管理
ViewModel 基于组件生命周期和引用计数实现自动生命周期管理。

**生命周期钩子：**
```dart
class MyViewModel extends StateViewModel<MyState> {
  @override
  void onCreate(InstanceArg arg) {
    super.onCreate(arg);
    print('ViewModel 已创建');
    // 初始化资源
  }

  @override
  void onBindVef(InstanceArg arg, String vefId) {
    super.onBindVef(arg, vefId);
    print('组件开始监听 (vefId: $vefId)');
    // 每次新组件开始监听时调用
  }

  @override
  void onUnbindVef(InstanceArg arg, String vefId) {
    super.onUnbindVef(arg, vefId);
    print('组件停止监听 (vefId: $vefId)');
    // 每次组件停止监听时调用
  }

  @override
  void onDispose(InstanceArg arg) {
    print('ViewModel 已销毁');
    // 清理资源
    super.onDispose(arg);
  }
}
```

**生命周期模式：**
- **自动生命周期（默认）**：ViewModel 在首次使用时创建，最后一个监听者解绑时自动销毁
- **单例模式**：使用 `aliveForever: true` 使实例永久存活（适用于全局服务如 AuthViewModel、ConfigViewModel）
- **共享实例**：使用 `key` 参数在多个组件间共享同一实例

```dart
// 不再被监听时自动销毁
final counterProvider = ViewModelProvider<CounterViewModel>(
  builder: () => CounterViewModel(),
);

// 永久存活（单例）
final authProvider = ViewModelProvider<AuthViewModel>(
  builder: () => AuthViewModel(),
  aliveForever: true, // 永不销毁
);

// 跨组件共享，所有监听者解绑时销毁
final userProvider = ViewModelProvider.arg<UserViewModel, int>(
  builder: (id) => UserViewModel(id),
  key: (id) => 'user_$id', // 通过 key 共享
);
```

**手动生命周期控制：**
```dart
// 强制重新创建 ViewModel
vef.recycle(myViewModel);

// 手动销毁特定实例（少见）
myViewModel.dispose();
```

**全局生命周期观察器：**
```dart
void main() {
  // 全局监控所有 ViewModel
  ViewModel.addLifecycle(MyGlobalObserver());

  runApp(MyApp());
}

class MyGlobalObserver implements ViewModelLifecycle {
  @override
  void onCreate<T extends ViewModel>(T vm, InstanceArg arg) {
    print('已创建：${vm.runtimeType}');
  }

  @override
  void onDispose<T extends ViewModel>(T vm, InstanceArg arg) {
    print('已销毁：${vm.runtimeType}');
  }

  // ... 其他回调
}
```

---

## 高级功能

### 1. 纯 Dart 访问（无需 Widget）
在任何 Dart 类中混入 `Vef` 以在组件外访问 ViewModel。

```dart
class StartupTask with Vef {
  Future<void> run() async {
    // 在纯 Dart 中访问 ViewModel
    final auth = vef.read(authProvider);
    await auth.checkLoginStatus();

    final config = vef.read(configProvider);
    await config.loadRemoteConfig();
  }

  @override
  void dispose() {
    super.dispose(); // 清理所有监听的 ViewModel
  }
}

// 使用
void main() async {
  final task = StartupTask();
  await task.run();
  task.dispose();

  runApp(MyApp());
}
```

### 2. ChangeNotifier 兼容性
从基于 ChangeNotifier 的代码逐步迁移。

```dart
class MyViewModel extends ChangeNotifierViewModel {
  int count = 0;

  void increment() {
    count++;
    notifyListeners(); // 标准 ChangeNotifier API
  }
}

// 同时支持 view_model 功能和 ChangeNotifier 消费者
```

### 3. 基于 Zone 的依赖解析
ViewModel 可以使用基于 Zone 的解析在异步上下文中访问其他 ViewModel。

```dart
class MyViewModel extends StateViewModel<MyState> {
  Future<void> fetchData() async {
    final result = await runWithVef(() async {
      // 可以在异步回调中访问 vef
      final auth = vef.read(authProvider);
      return await api.fetchData(auth.token);
    }, vef);

    setState(state.copyWith(data: result));
  }
}
```

### 4. 自定义状态相等性
定义自定义相等性以防止不必要的重建。

```dart
void main() {
  ViewModel.initialize(
    config: ViewModelConfig(
      // 自定义相等性检查
      equals: (prev, curr) {
        if (prev is MyState && curr is MyState) {
          return prev.id == curr.id; // 只在 ID 变化时重建
        }
        return identical(prev, curr);
      },
    ),
  );

  runApp(MyApp());
}
```

---

## 测试
使用 `setProxy` 轻松进行 Mock 测试。所有 provider 变体都支持代理。

**使用 Mock 的组件测试：**
```dart
testWidgets('使用 mock ViewModel 测试 UI', (tester) async {
  // 创建 mock
  final mockVM = MockUserViewModel();
  when(mockVM.state).thenReturn(UserState(name: 'Alice'));

  // 替换 provider
  userProvider.setProxy(ViewModelProvider(builder: () => mockVM));

  await tester.pumpWidget(MyApp());

  expect(find.text('Alice'), findsOneWidget);

  // 清理
  userProvider.clearProxy();
});
```

**测试基于参数的 Provider：**
```dart
testWidgets('测试带参数的 provider', (tester) async {
  final mockVM = MockUserViewModel();

  // 代理基于参数的 provider
  userProvider.setProxy(
    ViewModelProvider.arg<UserViewModel, int>(
      builder: (_) => mockVM, // 忽略参数，返回 mock
      key: (id) => 'user_$id',
    ),
  );

  await tester.pumpWidget(MyApp());

  // 使用任何用户 ID 测试 - 都返回 mock
  final vm1 = userProvider(42);
  final vm2 = userProvider(100);

  userProvider.clearProxy();
});
```

**纯 Dart 测试（无需 Widget）：**
```dart
test('ViewModel 逻辑测试', () {
  // 为测试创建自定义 Vef
  final vef = Vef();

  final vm = vef.watch(counterProvider);

  expect(vm.count, 0);

  vm.increment();
  expect(vm.count, 1);

  // 清理
  vef.dispose();
});
```

**StateViewModel 测试：**
```dart
test('状态变化发出通知', () {
  final vm = UserViewModel();
  final states = <UserState>[];

  vm.listenState(onChanged: (prev, curr) {
    states.add(curr);
  });

  vm.setState(UserState(name: 'Alice'));
  vm.setState(UserState(name: 'Bob'));

  expect(states.length, 2);
  expect(states[0].name, 'Alice');
  expect(states[1].name, 'Bob');

  vm.dispose();
});
```

**测试 ViewModel 依赖：**
```dart
test('ViewModel 可以访问其他 ViewModel', () {
  final vef = Vef();

  // 设置依赖
  final auth = vef.watch(authProvider);
  final user = vef.watch(userProvider(123));

  // Auth ViewModel 可从 user ViewModel 访问
  expect(user.isAuthenticated, true);

  vef.dispose();
});
```

---

## 全局配置
在 `main()` 中初始化以自定义系统行为：

```dart
void main() {
  ViewModel.initialize(
    config: ViewModelConfig(
      isLoggingEnabled: true,
      equals: (prev, curr) => prev == curr,
      onListenerError: (e, s, c) => logger.error(e, s),
    ),
  );
  runApp(MyApp());
}
```

| 参数 | 默认值 | 说明 |
| :--- | :--- | :--- |
| `isLoggingEnabled` | `false` | 开启/关闭调试日志 |
| `equals` | `identical` | 状态判断的相等逻辑 |
| `onListenerError` | `null` | 全局监听器错误回调 |
| `onDisposeError` | `null` | 全局销毁错误回调 |

---

## 最佳实践

### 1. 复杂状态优先使用 StateViewModel
```dart
// 推荐：使用 StateViewModel 的不可变状态
class TodoViewModel extends StateViewModel<TodoState> {
  TodoViewModel() : super(state: const TodoState());

  void addTodo(String title) {
    setState(state.copyWith(
      items: [...state.items, TodoItem(title)],
    ));
  }
}

// 避免：可变状态需要手动 notifyListeners
class TodoViewModel with ViewModel {
  List<TodoItem> items = [];

  void addTodo(String title) {
    items.add(TodoItem(title));
    notifyListeners(); // 容易忘记
  }
}
```

### 2. 使用 Key 共享实例
```dart
// 推荐：显式 key 用于共享
final userProvider = ViewModelProvider<UserViewModel>(
  key: 'current-user',
  builder: () => UserViewModel(),
);

// 推荐：基于参数的 provider 使用动态 key
final productProvider = ViewModelProvider.arg<ProductViewModel, int>(
  builder: (id) => ProductViewModel(id),
  key: (id) => 'product_$id',
);
```

### 3. 全局服务使用 aliveForever
```dart
// 推荐：单例服务保持存活
final authProvider = ViewModelProvider<AuthViewModel>(
  builder: () => AuthViewModel(),
  aliveForever: true, // 永不销毁
);

final themeProvider = ViewModelProvider<ThemeViewModel>(
  builder: () => ThemeViewModel(),
  aliveForever: true,
);
```

### 4. 区分 Read 和 Watch
```dart
// 推荐：build 中使用 watch()，回调中使用 read()
class _MyPageState extends State<MyPage> with ViewModelStateMixin {
  @override
  Widget build(BuildContext context) {
    final vm = vef.watch(myProvider); // 变化时重建

    return ElevatedButton(
      onPressed: () {
        // 不要在回调中 watch - 会导致不必要的重建
        vef.read(myProvider).doAction();
      },
      child: Text(vm.status),
    );
  }
}
```

### 5. 使用 listen() 处理副作用
```dart
class _MyPageState extends State<MyPage> with ViewModelStateMixin {
  @override
  void initState() {
    super.initState();

    // 推荐：listen() 用于导航、对话框、snackbar
    vef.listen(authProvider, onChanged: (vm) {
      if (vm.isLoggedOut) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = vef.watch(authProvider); // 用于 UI 更新
    return Text(vm.userName);
  }
}
```

### 6. 使用代码生成创建 Provider
```dart
// 推荐：使用 @GenProvider 自动生成
@GenProvider()
class CounterViewModel extends StateViewModel<CounterState> {
  factory CounterViewModel.provider() => CounterViewModel();
  // ...
}

// 运行：dart run build_runner build
// 自动生成：counterProvider
```

### 7. 结构化你的 ViewModel
```dart
// 推荐：清晰的关注点分离
class UserViewModel extends StateViewModel<UserState> {
  UserViewModel(this.repository) : super(state: const UserState());

  final UserRepository repository;

  // 供组件使用的公共 API
  Future<void> loadUser(int id) async {
    setState(state.copyWith(loading: true));
    try {
      final user = await repository.fetchUser(id);
      setState(state.copyWith(user: user, loading: false));
    } catch (e) {
      setState(state.copyWith(error: e.toString(), loading: false));
    }
  }

  // 计算属性
  bool get hasError => state.error != null;
  String get displayName => state.user?.name ?? '访客';
}
```

### 8. 测试策略
```dart
// 推荐：ViewModel 逻辑的纯单元测试
test('loadUser 正确更新状态', () async {
  final mockRepo = MockUserRepository();
  when(mockRepo.fetchUser(1)).thenAnswer((_) async => User(name: 'Alice'));

  final vm = UserViewModel(mockRepo);

  await vm.loadUser(1);

  expect(vm.state.user?.name, 'Alice');
  expect(vm.state.loading, false);

  vm.dispose();
});

// 使用 mock ViewModel 的组件测试
testWidgets('显示用户名', (tester) async {
  final mockVM = MockUserViewModel();
  when(mockVM.state).thenReturn(UserState(user: User(name: 'Alice')));

  userProvider.setProxy(ViewModelProvider(builder: () => mockVM));

  await tester.pumpWidget(MyApp());

  expect(find.text('Alice'), findsOneWidget);

  userProvider.clearProxy();
});
```

---

## 常见模式

### 1. 认证流程
```dart
// 全局认证服务
final authProvider = ViewModelProvider<AuthViewModel>(
  builder: () => AuthViewModel(),
  aliveForever: true, // 单例
);

class AuthViewModel extends StateViewModel<AuthState> {
  AuthViewModel() : super(state: const AuthState());

  Future<void> login(String email, String password) async {
    setState(state.copyWith(loading: true));
    try {
      final token = await authService.login(email, password);
      setState(state.copyWith(
        isLoggedIn: true,
        token: token,
        loading: false,
      ));
    } catch (e) {
      setState(state.copyWith(error: e.toString(), loading: false));
    }
  }

  void logout() {
    setState(const AuthState()); // 重置为初始状态
  }
}

// 在任何 ViewModel 中使用
class UserProfileViewModel extends StateViewModel<UserProfileState> {
  void loadProfile() {
    final auth = vef.read(authProvider);
    if (!auth.state.isLoggedIn) {
      // 处理未登录
      return;
    }

    // 使用认证令牌加载个人资料
    _fetchProfile(auth.state.token);
  }
}
```

### 2. 分页
```dart
class ProductListViewModel extends StateViewModel<ProductListState> {
  ProductListViewModel(this.repository)
      : super(state: const ProductListState());

  final ProductRepository repository;

  Future<void> loadMore() async {
    if (state.loading || !state.hasMore) return;

    setState(state.copyWith(loading: true));

    try {
      final newProducts = await repository.fetchProducts(
        page: state.currentPage + 1,
      );

      setState(state.copyWith(
        products: [...state.products, ...newProducts],
        currentPage: state.currentPage + 1,
        hasMore: newProducts.isNotEmpty,
        loading: false,
      ));
    } catch (e) {
      setState(state.copyWith(error: e.toString(), loading: false));
    }
  }
}
```

### 3. 表单验证
```dart
class LoginFormViewModel extends StateViewModel<LoginFormState> {
  LoginFormViewModel() : super(state: const LoginFormState());

  void setEmail(String email) {
    final error = _validateEmail(email);
    setState(state.copyWith(
      email: email,
      emailError: error,
    ));
  }

  void setPassword(String password) {
    final error = _validatePassword(password);
    setState(state.copyWith(
      password: password,
      passwordError: error,
    ));
  }

  bool get isValid =>
      state.emailError == null &&
      state.passwordError == null &&
      state.email.isNotEmpty &&
      state.password.isNotEmpty;

  String? _validateEmail(String email) {
    if (email.isEmpty) return '邮箱必填';
    if (!email.contains('@')) return '邮箱格式错误';
    return null;
  }

  String? _validatePassword(String password) {
    if (password.isEmpty) return '密码必填';
    if (password.length < 6) return '密码至少 6 个字符';
    return null;
  }
}

// 使用字段级重建
StateViewModelValueWatcher<LoginFormViewModel, LoginFormState>(
  stateViewModel: vm,
  selectors: [(s) => s.email, (s) => s.emailError],
  builder: (state) => TextField(
    decoration: InputDecoration(errorText: state.emailError),
    onChanged: vm.setEmail,
  ),
);
```

### 4. 主从模式
```dart
// 主：带共享实例的产品列表
final productProvider = ViewModelProvider.arg<ProductViewModel, int>(
  builder: (id) => ProductViewModel(id),
  key: (id) => 'product_$id',
);

// 列表页监听多个产品
class ProductListPage extends StatefulWidget {
  @override
  State<ProductListPage> createState() => _ProductListPageState();
}

class _ProductListPageState extends State<ProductListPage>
    with ViewModelStateMixin {
  @override
  Widget build(BuildContext context) {
    final ids = [1, 2, 3, 4, 5];

    return ListView.builder(
      itemCount: ids.length,
      itemBuilder: (context, index) {
        final vm = vef.watch(productProvider(ids[index]));
        return ListTile(
          title: Text(vm.state.name),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProductDetailPage(productId: ids[index]),
            ),
          ),
        );
      },
    );
  }
}

// 详情页复用相同实例
class _ProductDetailPageState extends State<ProductDetailPage>
    with ViewModelStateMixin {
  @override
  Widget build(BuildContext context) {
    final vm = vef.watch(productProvider(widget.productId));
    return Scaffold(
      appBar: AppBar(title: Text(vm.state.name)),
      body: Text(vm.state.description),
    );
  }
}
```

---

## 性能优化建议

1. **使用细粒度响应**：优先使用 `StateViewModelValueWatcher` 而不是完整组件重建
2. **利用暂停机制**：配置 `ViewModel.routeObserver` 防止后台页面重建
3. **避免在回调中使用 watch()**：使用 `vef.read()` 防止不必要的订阅
4. **使用计算属性**：在 getter 中计算派生值而不是存储在状态中
5. **批量状态更新**：一次性更新所有变化而不是多次 `setState` 调用

---

## 迁移指南

### 从 Provider 迁移
```dart
// 之前（Provider）
class MyPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MyViewModel>();
    return Text(vm.value);
  }
}

// 之后（view_model）
class MyPage extends StatefulWidget {
  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> with ViewModelStateMixin {
  @override
  Widget build(BuildContext context) {
    final vm = vef.watch(myProvider);
    return Text(vm.value);
  }
}
```

### 从 Riverpod 迁移
```dart
// 之前（Riverpod）
final counterProvider = StateNotifierProvider<Counter, int>(
  (ref) => Counter(),
);

class MyPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(counterProvider);
    return Text('$count');
  }
}

// 之后（view_model）
final counterProvider = ViewModelProvider<CounterViewModel>(
  builder: () => CounterViewModel(),
);

class _MyPageState extends State<MyPage> with ViewModelStateMixin {
  @override
  Widget build(BuildContext context) {
    final vm = vef.watch(counterProvider);
    return Text('${vm.count}');
  }
}
```

### 从 GetX 迁移
```dart
// 之前（GetX）
class CounterController extends GetxController {
  var count = 0.obs;
  void increment() => count++;
}

class MyPage extends StatelessWidget {
  final controller = Get.put(CounterController());

  @override
  Widget build(BuildContext context) {
    return Obx(() => Text('${controller.count}'));
  }
}

// 之后（view_model）
final counterProvider = ViewModelProvider<CounterViewModel>(
  builder: () => CounterViewModel(),
);

class _MyPageState extends State<MyPage> with ViewModelStateMixin {
  @override
  Widget build(BuildContext context) {
    final vm = vef.watch(counterProvider);
    return Text('${vm.count}');
  }
}
```

---

## 常见问题

### Q：应该使用 StateViewModel 还是 ViewModel mixin？
**A：** 当需要不可变状态管理、自动相等性检查和状态历史时使用 `StateViewModel<T>`。对于简单场景或从 ChangeNotifier 迁移时使用 `ViewModel` mixin。大多数情况推荐使用 StateViewModel。

### Q：与 Provider/Riverpod/GetX 有什么区别？
**A：**
- **vs Provider**：无需 InheritedWidget，不依赖 BuildContext，自动生命周期，ViewModel 可互访
- **vs Riverpod**：不强制 ConsumerWidget，语法更简单，无复杂图概念，只需添加 mixin
- **vs GetX**：类型安全，无全局状态污染，Flutter 原生设计，更好的可测试性，显式依赖

### Q：需要用根组件包裹应用吗？
**A：** 不需要。只需给 State 类添加 `ViewModelStateMixin`。可选择将 `ViewModel.routeObserver` 添加到 `navigatorObservers` 以启用路由感知暂停。

### Q：ViewModel 可以访问其他 ViewModel 吗？
**A：** 可以！ViewModel 内置 `vef` 访问，可以使用 `vef.read()` 或 `vef.watch()` 访问其他 ViewModel。依赖关系会自动跟踪。

### Q：如何跨页面共享 ViewModel 实例？
**A：** 两种方式：
1. 使用带 `key` 的 provider：
```dart
final userProvider = ViewModelProvider<UserViewModel>(
  builder: () => UserViewModel(),
  key: 'current-user', // 相同 key = 相同实例
);
```
2. 直接通过 key 读取：
```dart
final user = vef.readCached<UserViewModel>(key: 'current-user');
```

### Q：ViewModel 何时被销毁？
**A：** 默认情况下，当最后一个监听者解绑时 ViewModel 被销毁（引用计数）。对于永不销毁的单例服务使用 `aliveForever: true`。

### Q：如何防止页面不可见时重建？
**A：** `ViewModelStateMixin` 的暂停机制是自动的。只需注册 `ViewModel.routeObserver`：
```dart
MaterialApp(
  navigatorObservers: [ViewModel.routeObserver],
  // ...
)
```

### Q：可以用于 StatelessWidget 吗？
**A：** 可以，使用 `ViewModelStatelessMixin` 或 `ViewModelBuilder` 组件，但推荐使用带 `ViewModelStateMixin` 的 `StatefulWidget` 以实现自动生命周期管理。

### Q：如何测试 ViewModel？
**A：** 多种方式：
1. 纯单元测试：直接测试 ViewModel 逻辑，无需组件
2. 使用 mock 的组件测试：使用 `provider.setProxy()` 替换为 mock
3. 集成测试：使用真实 ViewModel 测试完整组件树

### Q：支持代码生成吗？
**A：** 支持！使用 `view_model_generator` 配合 `@GenProvider` 注解自动生成 provider。支持最多 4 个构造函数参数的 ViewModel。

### Q：如何处理异步操作？
**A：** 使用 `update()` 方法：
```dart
Future<void> loadData() async {
  await update(() async {
    final data = await repository.fetch();
    _data = data;
  }); // 自动通知监听者
}
```

### Q：可以在组件外使用吗（纯 Dart）？
**A：** 可以！在任何 Dart 类中混入 `Vef`：
```dart
class MyService with Vef {
  void doWork() {
    final auth = vef.read(authProvider);
    // 在纯 Dart 中使用 ViewModel
  }
}
```

### Q：如何从其他状态管理方案迁移？
**A：** 参见上面的[迁移指南](#迁移指南)部分，有 Provider、Riverpod 和 GetX 的具体示例。

### Q：性能如何？
**A：** 库包含多项优化：
- 组件不可见时暂停机制延迟更新
- 使用 `StateViewModelValueWatcher` 的细粒度响应
- 引用计数防止内存泄漏
- 基于 Zone 的依赖解析效率高

### Q：支持 Flutter Web/Desktop 吗？
**A：** 支持！库适用于所有 Flutter 平台（移动端、Web、桌面端）。

---

## 贡献

欢迎贡献！请先阅读[贡献指南](https://github.com/lwj1994/flutter_view_model/blob/main/CONTRIBUTING.md)。

## 许可证

本项目基于 MIT 许可证 - 详见 [LICENSE](https://github.com/lwj1994/flutter_view_model/blob/main/LICENSE) 文件。

## 链接

- [GitHub 仓库](https://github.com/lwj1994/flutter_view_model)
- [Pub 包](https://pub.dev/packages/view_model)
- [架构指南](https://github.com/lwj1994/flutter_view_model/blob/main/ARCHITECTURE_GUIDE_ZH.md)
- [英文文档](README.md)
- [Agent Skills](https://github.com/lwj1994/flutter_view_model/blob/main/skills/view_model/SKILL.md)
- [问题跟踪](https://github.com/lwj1994/flutter_view_model/issues)
