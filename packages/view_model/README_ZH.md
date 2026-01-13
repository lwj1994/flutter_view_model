<p align="center">
  <img src="https://lwjlol-images.oss-cn-beijing.aliyuncs.com/logo.png" alt="ViewModel Logo" height="96" />
</p>

# view_model

> Flutter 缺失的 ViewModel 方案 — 万物皆 ViewModel ✨

| Package | Version |
| :--- | :--- |
| **view_model** | [![Pub Version](https://img.shields.io/pub/v/view_model)](https://pub.dev/packages/view_model) |
| **view_model_annotation** | [![Pub Version](https://img.shields.io/pub/v/view_model_annotation)](https://pub.dev/packages/view_model_annotation) |
| **view_model_generator** | [![Pub Version](https://img.shields.io/pub/v/view_model_generator)](https://pub.dev/packages/view_model_generator) |

[![Codecov](https://img.shields.io/codecov/c/github/lwj1994/flutter_view_model/main)](https://app.codecov.io/gh/lwj1994/flutter_view_model/tree/main)

[更新日志](https://github.com/lwj1994/flutter_view_model/blob/main/packages/view_model/CHANGELOG.md) | [English Doc](https://github.com/lwj1994/flutter_view_model/blob/main/README.md)

## 目录

- [为什么要用 view_model？](#为什么要用-view_model)
- [📦 安装搞起](#-安装搞起)
- [⚡️ 三步快速上手](#️-三步快速上手)
- [🌈 核心功能详解](#-核心功能详解)
  - [1. 万能访问 (Vef)](#1-万能访问-vef-️)
  - [2. 不可变状态 (StateViewModel)](#2-不可变状态-stateviewmodel-)
  - [3. 依赖注入 (参数传递)](#3-依赖注入-参数传递-)
  - [4. 实例共享 (Keys)](#4-实例共享-keys-)
  - [5. 自动生命周期](#5-自动生命周期-️)
  - [6. 长生不老 (全局状态)](#6-长生不老-全局状态)
  - [7. 架构模式 (Clean Architecture)](#7-架构模式-clean-architecture-️)
  - [8. 代码生成 (强烈推荐)](#8-代码生成-强烈推荐-)
- [🧪 测试指南](#-测试指南)
- [� 避坑指南 (必看)](#-避坑指南-必看)
- [�🔧 全局配置](#-全局配置)
- [📄 License](#-license)

## 为什么要用 view_model？

**万物皆 ViewModel，任何类都能处处访问。**

其他方案让你二选一：
- 全局状态（到处共享，容易混乱）
- 手动 Provider（样板代码多 + BuildContext 地狱）

**view_model** 两者兼得，绝绝子！

* ✅ **万物皆 ViewModel** - Repository、Service、任何类都能是 ViewModel
* ✅ **处处可访问** - 彻底告别 `BuildContext` 传参
* ✅ **默认隔离** - 每个 Widget 独享实例，互不干扰
* ✅ **按需共享** - 加个 `key` 就能随处复用
* ✅ **零样板** - 没有复杂的胶水代码
* ✅ **自动生命周期** - 自动创建，自动销毁，省心！

## 📦 安装搞起

```yaml
dependencies:
  view_model: ^latest_version

dev_dependencies:
  build_runner: ^latest_version
  view_model_generator: ^latest_version # 强烈推荐，用了就回不去！
```

## ⚡️ 三步快速上手

### 1. 定义 ViewModel

继承 `ViewModel`，用 `update()` 通知界面刷新。

```dart
class CounterViewModel extends ViewModel {
  int count = 0;

  void increment() {
    update(() => count++);
  }
}
```

### 2. 创建 Provider

定义一个全局 Provider，Widget 就靠它找到你的 ViewModel。

```dart
final counterProvider = ViewModelProvider<CounterViewModel>(
  builder: () => CounterViewModel(),
);
```

*(小贴士：用 `view_model_generator` 可以跳过这一步哦！)* 😉

### 3. 在 Widget 中使用

在 `StatefulWidget` 中混入 `ViewModelStateMixin`。

```dart
class CounterPage extends StatefulWidget {
  @override
  State<CounterPage> createState() => _CounterPageState();
}

class _CounterPageState extends State<CounterPage> with ViewModelStateMixin {
  @override
  Widget build(BuildContext context) {
    // 监听 provider。ViewModel 更新时，Widget 会自动重建。
    final vm = vef.watch(counterProvider);

    return Scaffold(
      body: Center(
        child: Text('${vm.count}'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: vm.increment,
        child: Icon(Icons.add),
      ),
    );
  }
}
```

## 🌈 核心功能详解

### 1. 万能访问 (`Vef`) 🗝️

**核心概念**：`Vef` 是一个 **Mixin**，可以混入到 **任何类** 中，不只是 Widget！

`vef` (ViewModel Execution Framework) 是你即取即用 ViewModel 的神器。

#### 在 Widget 中 (内置支持)

用了 `ViewModelStateMixin`，`vef` 自动到手：

```dart
class _MyPageState extends State<MyPage> with ViewModelStateMixin {
  @override
  Widget build(BuildContext context) {
    final vm = vef.watch(myProvider); // vef 直接用
    return Text(vm.data);
  }
}
```

#### 在 ViewModel 中 (内置支持)

**ViewModel 已经内置了 `vef`！** 你可以直接调用其他 ViewModel，套娃也没问题：

```dart
// ✅ ViewModel 调用其他 ViewModel
class CartViewModel extends ViewModel {
  void checkout() {
    // 直接用 vef，不需要 extra mixin
    final userVM = vef.read(userProvider);
    final paymentVM = vef.read(paymentProvider);

    processOrder(userVM.user, paymentVM.method);
  }
}

class UserViewModel extends StateViewModel<UserState> {
  void updateTheme() {
    // 访问全局设置 VM
    final settingsVM = vef.read(settingsProvider);
    applyTheme(settingsVM.state.theme);
  }
}
```

#### 在任何类中 - "万物皆 ViewModel"

**设计哲学**：Repository、Service、Helper... 它们都可以是 ViewModel！只需继承 `ViewModel`，马上拥有访问能力，告别 `BuildContext`。

```dart
// ✅ Repository 也是 ViewModel
class UserRepository extends ViewModel {
  Future<User> fetch() async {
    // 轻松拿到 AuthViewModel 的 token
    final authVM = vef.read(authProvider);
    return api.get('/user', token: authVM.token);
  }
}

// ✅ Service 也是 ViewModel
class AnalyticsService extends ViewModel {
  void trackEvent(String event) {
    final userVM = vef.read(userProvider);
    analytics.log(event, userId: userVM.userId);
  }
}

// ✅ 测试 Helper 也是 ViewModel
class TestHelper extends ViewModel {
  void setupTestData() {
    final authVM = vef.read(authProvider);
    authVM.loginAsTestUser();
  }
}
```

**ViewModel 之间协同工作**：

```dart
class UserProfileViewModel extends ViewModel {
  final UserRepository _repo;
  UserProfileViewModel(this._repo);

  Future<void> loadUser() async {
    // 通过 vef 访问其他 ViewModel
    final authVM = vef.read(authProvider);
    final user = await _repo.fetch(); // Repo 内部也用 vef

    // 通知其他 ViewModel
    vef.read(cacheProvider).updateCache(user);
  }
}
```

**为什么说 "万物皆 ViewModel" 真香？**
- ✅ **无需 Context** - 哪里都能拿数据，不再透传 Context
- ✅ **统一 DI** - 全层级统一的依赖注入模式
- ✅ **自动引用计数** - 内存管理全自动
- ✅ **可测试** - 这里的所有依赖都能 Mock
- ✅ **灵活** - 怎么舒服怎么写

#### Vef 方法查询表

| 方法 | 用法 |
| :--- | :--- |
| `vef.watch(provider)` | **获取 + 监听**。返回实例并订阅更新（触发重建）。在 `build()` 或 `initState()` 里放心用！ |
| `vef.read(provider)` | **仅获取**。返回实例但不订阅。**不会**触发重建。在回调（如 `onPressed`）里用它！ |
| `vef.listen(provider)` | **仅监听**。订阅变化来处理副作用（比如弹窗），不重建 UI。会自动释放哦。 |
| `vef.watchCached(key:)` | 通过 key 获取已存在的实例（只能拿现成的，不创建）。 |
| `vef.readCached(key:)` | 通过 key 读取已存在的实例（不监听）。 |

### 2. 不可变状态 (`StateViewModel`) 🔒

对于复杂状态，不可变对象 (Immutable) 才是 YYDS！`StateViewModel` 专门为此设计。

```dart
// 1. 状态类 (带上 copyWith)
class UserState {
  final String name;
  final bool isLoading;

  UserState({this.name = '', this.isLoading = false});

  // 必须：copyWith 方法用于不可变更新
  UserState copyWith({String? name, bool? isLoading}) {
    return UserState(
      name: name ?? this.name,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

// 2. ViewModel
class UserViewModel extends StateViewModel<UserState> {
  UserViewModel() : super(state: UserState());

  void loadUser() async {
    setState(state.copyWith(isLoading: true)); // 更新状态
    // ... 请求接口 ...
    setState(state.copyWith(isLoading: false, name: 'Alice'));
  }
}
```

> **墙裂推荐**：用 [freezed](https://pub.dev/packages/freezed) 或 [built_value](https://pub.dev/packages/built_value) 自动生成 `copyWith`，省时省力！

#### 监听变化

只想在特定状态变化时搞事情（比如弹窗、跳转）？完全没问题！

```dart
// 监听特定属性
vef.listenStateSelect(
  userProvider,
  selector: (state) => state.isLoading,
  onChanged: (prev, isLoading) {
    if (isLoading) {
      showLoadingDialog();
    } else {
      dismissLoadingDialog();
    }
  },
);

// 监听整个状态
vef.listenState(userProvider, onChanged: (prev, state) {
  print('状态变啦：$prev -> $state');
});
```

### 3. 依赖注入 (参数传递) 💉

ViewModel 需要外部参数（比如 ID 或 Repository）？必须支持！

```dart
// 定义需要参数 (int id) 的 provider
final userProvider = ViewModelProvider.arg<UserViewModel, int>(
  builder: (int id) => UserViewModel(id),
);

// 在 Widget 中使用
final vm = vef.watch(userProvider(123)); // 传参只需一步，太方便了
```

### 4. 实例共享 (Keys) 🔗

**默认行为：隔离**
当你调用 `vef.watch(provider)`，你拿到的是这个 Widget **独享**的全新实例。别的 Widget 用同一个 provider，拿到的是另一个实例。（再也不用担心状态污染！）

**共享行为：Keys**
想在不同 Widget 间（比如商品详情页和它的 Header）共享同一个 ViewModel？加个 `key` 就行！

**场景**：`ProductPage` 和子组件 `ProductHeader` 需要共享数据。

```dart
// 1. 定义 provider，key 基于参数生成
final productProvider = ViewModelProvider.arg<ProductViewModel, String>(
  builder: (id) => ProductViewModel(id),
  key: (id) => 'product_$id', // Key 相同，实例就相同
);

// 2. 父组件 (Page)
class ProductPage extends StatefulWidget {
  final String productId;
  // ...
  build(context) {
    // 创建或查找 key 为 'product_123' 的实例
    final vm = vef.watch(productProvider(productId));
    // ...
  }
}

// 3. 子组件 (Header)
class ProductHeader extends StatefulWidget {
  final String productId;
  // ...
  build(context) {
    // Key 一样，拿到的就是同一个实例！完美同步！
    final vm = vef.watch(productProvider(productId)); 
    return Text(vm.title);
  }
}
```

### 5. 自动生命周期 ♻️

`view_model` 使用严格的**引用计数**来管理内存，不用操心！

1.  **创建**：第一次 `watch`、`read` 或 `listen` 时，ViewModel 被创建（引用 +1）。
2.  **存活**：只要 Widget 还在，引用就在。
    *   `watch`：持有引用 + 监听。
    *   `read`：持有引用（不监听）。
    *   `listen`：内部持有引用。
3.  **销毁**：Widget 销毁时，引用 -1。当引用归零，ViewModel 自动 `dispose()`。👋 拜拜了您嘞！

> **例外 (Keep Alive)**：如果你在 provider 里设置了 `aliveForever: true`，那它就**永远不会**自动销毁，哪怕引用归零。这就变成全局单例啦！

### 6. 长生不老 (全局状态)

默认情况下，ViewModel 无人使用时会自动销毁。但有些 ViewModel 需要“长生不老”（比如用户会话、应用设置）。

你可以通过设置 `aliveForever: true` 来实现。**强烈建议同时指定 `key`**，以便在全局范围内唯一标识和查找该实例。

#### 手动定义

```dart
final appSettingsProvider = ViewModelProvider<AppSettingsViewModel>(
  builder: () => AppSettingsViewModel(),
  key: 'app_settings', // 指定一个全局 key
  aliveForever: true, // 这个实例永远不会被销毁
);
```

#### 使用生成器 (推荐)

```dart
@GenProvider(key: 'app_settings', aliveForever: true)
class AppSettingsViewModel extends ViewModel {}
```

注意：即使 `aliveForever` 为 true，ViewModel 依然是 **懒加载** 的。只有第一次访问时才会创建。

### 7. 架构模式 (Clean Architecture) 🏗️

怎么用 `view_model` 搭建 Clean Architecture？抄作业时间到！📝

```dart
// ============================================
// 1️⃣ 数据层 - Repository 也是 ViewModel
// ============================================
@GenProvider()
class UserRepository extends ViewModel {
  final ApiClient _api;

  UserRepository(this._api);

  // ✅ Repository 是 ViewModel - 可以访问其他 VM
  Future<User> fetchUser(int id) async {
    final authVM = vef.read(authProvider);
    return _api.get('/users/$id',
      headers: {'Authorization': 'Bearer ${authVM.token}'}
    );
  }

  Future<void> updateUser(User user) async {
    final authVM = vef.read(authProvider);
    await _api.put('/users/${user.id}', user.toJson(),
      headers: {'Authorization': 'Bearer ${authVM.token}'}
    );
  }
}

// ============================================
// 2️⃣ 领域层 - 全局 & 业务 ViewModel
// ============================================
@GenProvider(key: 'auth', aliveForever: true)
class AuthViewModel extends StateViewModel<AuthState> {
  AuthViewModel() : super(state: AuthState.unauthenticated());

  String? get token => state.token;
  bool get isAuthenticated => state.isAuthenticated;

  Future<void> login(String email, String password) async {
    setState(state.copyWith(isLoading: true));
    try {
      final result = await authService.login(email, password);
      setState(AuthState.authenticated(result.token, result.user));
    } catch (e) {
      setState(state.copyWith(error: e.toString(), isLoading: false));
    }
  }

  void logout() {
    setState(AuthState.unauthenticated());
  }
}

@GenProvider()
class UserViewModel extends StateViewModel<UserState> {
  final UserRepository _repository;

  UserViewModel(this._repository) : super(state: UserState.initial());

  Future<void> loadUser(int id) async {
    setState(state.copyWith(isLoading: true));
    try {
      // ✅ Repository 内部自己搞定 Auth，这里只管业务
      final user = await _repository.fetchUser(id);
      setState(state.copyWith(user: user, isLoading: false));
    } catch (e) {
      setState(state.copyWith(error: e.toString(), isLoading: false));
    }
  }

  Future<void> updateProfile(String name) async {
    final updated = state.user!.copyWith(name: name);
    await _repository.updateUser(updated);
    setState(state.copyWith(user: updated));

    // 通知其他 ViewModel
    vef.read(profileCacheProvider).invalidate();
  }
}

// ============================================
// 3️⃣ 表现层 - Widgets
// ============================================
class UserProfilePage extends StatefulWidget {
  final int userId;
  const UserProfilePage({required this.userId});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage>
    with ViewModelStateMixin {

  @override
  void initState() {
    super.initState();
    // 页面打开加载数据
    vef.read(userProvider).loadUser(widget.userId);

    // 监听 Auth 变化 (比如退出登录)
    vef.listenStateSelect(
      authProvider,
      selector: (state) => state.isAuthenticated,
      onChanged: (prev, isAuth) {
        if (!isAuth) {
          Navigator.of(context).pushReplacementNamed('/login');
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final userVM = vef.watch(userProvider);
    final authVM = vef.watch(authProvider);

    if (userVM.state.isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(userVM.state.user?.name ?? 'Profile'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: authVM.logout,
          ),
        ],
      ),
      body: Column(
        children: [
          Text('Name: ${userVM.state.user?.name}'),
          Text('Email: ${userVM.state.user?.email}'),
          ElevatedButton(
            onPressed: () => _showEditDialog(userVM),
            child: Text('Edit Profile'),
          ),
        ],
      ),
    );
  }
  
  // ... helpers
}
```

**划重点**：
- 🔹 **"万物皆 ViewModel"** - 既然都是 ViewModel，那一套逻辑通吃！
- 🔹 **无需 Context** - 组件间通信靠 `vef`，清爽！
- 🔹 **Repository 是 ViewModel** - 它可以自己管理依赖（比如 Auth）。
- 🔹 **各司其职** - 业务 ViewModel 专注逻辑，Repository 专注数据。
- 🔹 **全局状态** (Auth) 用 `aliveForever: true` + `key` 搞定。
- 🔹 **统一的 DI** - 全层级一样的写法，强迫症福音！

### 8. 代码生成 (强烈推荐) 🤖

手写 `ViewModelProvider` 太麻烦？用 `@genProvider` 解放双手！

```dart
@genProvider
class MyViewModel extends ViewModel {}
```

运行 `dart run build_runner build`，Provider 自动生成！
详情看这里 👉 [view_model_generator](../view_model_generator/README_ZH.md)

## 🧪 测试指南

### Widget 测试

用 `setProxy` 就能轻松 Mock 任何 ViewModel！

```dart
testWidgets('显示用户数据', (tester) async {
  final mockVM = MockUserViewModel();
  when(mockVM.state).thenReturn(UserState(user: testUser));

  // 用 Mock 替换真实实现
  userProvider.setProxy(
    ViewModelProvider(builder: () => mockVM)
  );

  await tester.pumpWidget(MyApp());

  expect(find.text(testUser.name), findsOneWidget);
});
```

### 单元测试 (Repository ViewModel)

ViewModel 依赖其他 ViewModel 怎么测？Mock 这个依赖！

```dart
void main() {
  late UserRepository repository;
  late MockAuthViewModel mockAuthVM;

  setUp(() {
    mockAuthVM = MockAuthViewModel();
    when(mockAuthVM.token).thenReturn('test-token');

    // Mock auth 模块
    authProvider.setProxy(
      ViewModelProvider(builder: () => mockAuthVM)
    );

    repository = UserRepository(mockApiClient);
  });

  tearDown(() {
    authProvider.clearProxy();
  });

  test('请求带上了 token', () async {
    // 仓库内部会 vef.read(authProvider)
    await repository.fetchUser(123);

    // 验证 token 是否被使用
    verify(mockApiClient.get(
      '/users/123',
      headers: {'Authorization': 'Bearer test-token'}
    ));
  });
}
```

### 单元测试 (依赖其他 VM 的 VM)

当你的 ViewModel 内部也用了 `vef`，测试时需要手动创建一个 Vef 环境：

```dart
// 测试辅助类
class TestVef with Vef {}

void main() {
  test('CartViewModel 访问 UserViewModel', () {
    // 创建测试用的 Vef 环境
    final testVef = TestVef();

    final mockUserVM = MockUserViewModel();
    when(mockUserVM.user).thenReturn(testUser);

    userProvider.setProxy(
      ViewModelProvider(builder: () => mockUserVM)
    );

    // ✅ 通过 Vef 创建 CartViewModel，这样它才能拿到 Mock 的依赖
    final cartVM = testVef.read(cartProvider);
    cartVM.checkout();

    // 验证调用
    verify(mockUserVM.user).called(1);

    testVef.dispose();
  });
}
```

## � 避坑指南 (必看)

### ❌ `aliveForever` 忘了加 `key`

如果只加 `aliveForever` 不加 `key`，每个页面还是会创建新实例（这就尴尬了）。

```dart
// ❌ 错！还是多实例
@GenProvider(aliveForever: true)
class AuthViewModel extends ViewModel {}

// ✅ 对！全局单例
@GenProvider(key: 'auth', aliveForever: true)
class AuthViewModel extends ViewModel {}
```

### ❌ State 类忘了 `copyWith`

`StateViewModel` 默认比较内存地址，想更新状态，必须给个**新对象**！

`copyWith` 是标准做法：

```dart
// ❌ 错 - 没有 copyWith
class MyState {
  final int count;
  MyState(this.count);
}

// ✅ 对 - 有 copyWith
class MyState {
  final int count;
  MyState(this.count);

  MyState copyWith({int? count}) => MyState(count ?? this.count);
}

// ✅ 完美 - 用 freezed/built_value 自动生成
@freezed
class MyState with _$MyState {
  factory MyState({required int count}) = _MyState;
}
```

## �🔧 全局配置

在 `main()` 里可以配置全局行为。

```dart
void main() {
  ViewModel.initialize(
    config: ViewModelConfig(
      // 开启日志大法 (Debug 必备)
      isLoggingEnabled: true,

      // 自定义状态比较逻辑 (可选)
      equals: (prev, current) {
        // 如果你像用 Equatable...
        if (prev is Equatable && current is Equatable) {
          return prev == current;
        }
        return identical(prev, current);
      },

      // 监听器报错处理 (v0.13.0 新增)
      onListenerError: (error, stackTrace, context) {
        // 上报给 Crashlytics
        FirebaseCrashlytics.instance.recordError(error, stackTrace);

        if (kDebugMode) {
          print('❌ $context 报错了: $error');
        }
      },

      // 销毁时报错处理 (v0.13.0 新增)
      onDisposeError: (error, stackTrace) {
        print('⚠️ 销毁时出错了: $error');
      },
    ),

    // 添加全局导航/生命周期观察者
    lifecycles: [
      MyViewModelObserver(),
    ],
  );

  runApp(MyApp());
}

// 自定义观察者示例
class MyViewModelObserver extends ViewModelLifecycle {
  @override
  void onCreate(ViewModel viewModel, InstanceArg arg) {
    print('✅ 创建了: ${viewModel.runtimeType}');
  }

  @override
  void onDispose(ViewModel viewModel, InstanceArg arg) {
    print('🗑️ 销毁了: ${viewModel.runtimeType}');
  }
}
```

**v0.13.0 新特性**：
- ✨ `onListenerError`: 捕获 `notifyListeners()` 和状态监听里的异常，防止一处崩全盘崩。
- ✨ `onDisposeError`: 捕获资源清理时的异常。
- 🎯 对于崩溃上报和调试非常有帮助！

## 📄 License

MIT License - 详见 [LICENSE](./LICENSE) 文件。
