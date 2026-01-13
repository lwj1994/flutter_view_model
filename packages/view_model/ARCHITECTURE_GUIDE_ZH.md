# 🏗️ 架构 & 最佳实践指南

> **用 view_model 构建可扩展、可测试的 Flutter 应用**
>
> 本指南教你如何利用 **"万物皆 ViewModel"** 哲学打造整洁架构

---

## 💡 核心哲学："万物皆 ViewModel"

在 `view_model` 中，业务逻辑独立于 UI 之外——每一层都能从 ViewModel 能力中获益。通过使用 **`with ViewModel`**，任何类都能获得统一访问、自动生命周期管理，以及通过 **Vef (Custom Ref)** 框架实现的零摩擦依赖协调。

**核心原则**：无论是 Repository、Service 还是 Domain ViewModel——只需加上 `with ViewModel` 就能获得超能力！🚀

---

## 🏛️ 分层架构

### 1️⃣ 数据层（Repositories）

**职责**：处理网络请求、本地存储和数据转换。

**模式**：使用 **`with ViewModel`** 来访问全局状态（如 Auth token），无需通过构造函数传递依赖。

```dart
@genProvider
class UserRepository with ViewModel {
  final ApiClient _api;

  UserRepository(this._api);

  Future<User> getUser() async {
    // 通过内置的 vef 直接访问 auth 状态！
    final authVM = vef.read(authProvider);
    return _api.get('/me', headers: {'Auth': authVM.token});
  }

  Future<void> updateUser(User user) async {
    final authVM = vef.read(authProvider);
    await _api.put('/users/${user.id}', user.toJson(),
      headers: {'Auth': authVM.token}
    );
  }
}
```

**为什么这样做有效**：
- ✅ 避免构造函数被 auth 依赖污染
- ✅ Repositories 可以干净地协调全局状态
- ✅ 通过 `setProxy` 轻松 mock auth 进行测试

---

### 2️⃣ 领域层（ViewModels）

**职责**：协调数据层和 UI，管理业务逻辑和状态。

**模式**：不可变状态用 **`StateViewModel<T>`**，简单可变状态用 **`with ViewModel`**。

#### 不可变状态模式（推荐）

```dart
@genProvider
class ProfileViewModel extends StateViewModel<ProfileState> {
  final UserRepository _repo;

  ProfileViewModel(this._repo) : super(state: ProfileState.initial());

  Future<void> load() async {
    setState(state.copyWith(isLoading: true));

    try {
      final user = await _repo.getUser();
      setState(state.copyWith(user: user, isLoading: false));
    } catch (e) {
      setState(state.copyWith(error: e.toString(), isLoading: false));
    }
  }

  Future<void> updateProfile(String name) async {
    final updated = state.user!.copyWith(name: name);
    await _repo.updateUser(updated);
    setState(state.copyWith(user: updated));
  }
}
```

#### 可变状态模式（简单场景）

```dart
@genProvider
class CounterViewModel with ViewModel {
  int count = 0;

  void increment() {
    update(() => count++);  // 自动通知监听者
  }
}
```

**ViewModels 之间的协调**：

```dart
class CartViewModel with ViewModel {
  void checkout() {
    // 通过内置 vef 直接访问其他 ViewModels
    final userVM = vef.read(userProvider);
    final paymentVM = vef.read(paymentProvider);

    processOrder(userVM.user, paymentVM.method);
  }
}
```

---

### 3️⃣ 表现层（Widgets）

**职责**：展示 UI 和处理用户交互。

**模式**：在 State 类中混入 **`ViewModelStateMixin`**。

```dart
class ProfilePage extends StatefulWidget {
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with ViewModelStateMixin {

  @override
  void initState() {
    super.initState();
    // 页面打开时加载数据
    vef.read(profileProvider).load();
  }

  @override
  Widget build(BuildContext context) {
    // 状态变化时自动重建
    final vm = vef.watch(profileProvider);

    if (vm.state.isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(title: Text(vm.state.user?.name ?? 'Profile')),
      body: Column(
        children: [
          Text('Email: ${vm.state.user?.email}'),
          ElevatedButton(
            onPressed: () => _showEditDialog(vm),
            child: Text('编辑资料'),
          ),
        ],
      ),
    );
  }
}
```

---

## ✅ 最佳实践

### 1. 使用 `with` 而不是 `extends`

**为什么？** Dart 3 的 mixin 支持组合优于继承——更灵活，类层次结构更清晰。

```dart
// ✅ 推荐
@genProvider
class MyLogic with ViewModel { ... }

// ⚠️ 可用但不够灵活
@genProvider
class MyLegacyLogic extends ViewModel { ... }
```

---

### 2. 选择正确的方法

| 使用场景 | 方法 | 原因 |
|---------|------|-----|
| 在 `build()` 里 | `vef.watch()` | 数据变化时重建 widget |
| 事件处理（`onPressed`） | `vef.read()` | 只需访问，无需重建 |
| 副作用（导航） | `vef.listen()` | 响应变化但不重建 |
| 访问共享实例 | `vef.watchCached(key:)` | 通过 key 获取特定实例 |

**示例**：

```dart
class _MyPageState extends State<MyPage> with ViewModelStateMixin {
  @override
  void initState() {
    super.initState();

    // 监听副作用
    vef.listen(authProvider, (auth) {
      if (!auth.isAuthenticated) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // watch 用于重建
    final vm = vef.watch(profileProvider);

    return ElevatedButton(
      // read 用于操作
      onPressed: () => vef.read(profileProvider).refresh(),
      child: Text(vm.state.user?.name ?? '访客'),
    );
  }
}
```

---

### 3. 用 Key 共享状态

**默认行为**：每个 widget 独立的实例。

**共享状态**：添加 `key` 在多个 widget 间共享同一个实例。

```dart
// 全局单例
final authProvider = ViewModelProvider(
  builder: () => AuthViewModel(),
  key: 'auth',
  aliveForever: true,
);

// 按 ID 共享
final productProvider = ViewModelProvider.arg<ProductViewModel, String>(
  builder: (id) => ProductViewModel(id),
  key: (id) => 'product_$id',  // 相同 ID = 相同实例
);
```

---

### 4. 保持状态不可变

使用 `StateViewModel` 时，始终将 state 视为不可变的。用 `copyWith` 更新状态。

**为什么？** 可预测的重建、更容易调试、支持时间旅行调试。

```dart
// ❌ 错误 - 直接修改状态
void badUpdate() {
  state.count++;  // 别这样做！
  setState(state);
}

// ✅ 正确 - 创建新状态
void goodUpdate() {
  setState(state.copyWith(count: state.count + 1));
}
```

**专业提示**：用 [Freezed](https://pub.dev/packages/freezed) 自动生成带 `copyWith` 的不可变类：

```dart
@freezed
class ProfileState with _$ProfileState {
  factory ProfileState({
    User? user,
    @Default(false) bool isLoading,
    String? error,
  }) = _ProfileState;

  factory ProfileState.initial() => ProfileState();
}
```

---

### 5. 处理生命周期钩子

ViewModels 提供生命周期钩子用于初始化和清理：

```dart
class MyViewModel with ViewModel {
  late StreamSubscription _subscription;

  @override
  void onCreate() {
    super.onCreate();
    // 初始化资源
    _subscription = someStream.listen(_handleData);
  }

  @override
  void onDispose() {
    // 清理资源
    _subscription.cancel();
    super.onDispose();
  }
}
```

**更简单的方式**：使用 `addDispose` 自动清理：

```dart
class MyViewModel with ViewModel {
  @override
  void onCreate() {
    super.onCreate();

    final subscription = someStream.listen(_handleData);
    addDispose(() => subscription.cancel());  // dispose 时自动清理
  }
}
```

---

## 🧪 测试策略

### 单元测试 ViewModels

不依赖 Flutter 测试业务逻辑：

```dart
void main() {
  test('计数器自增', () {
    final vm = CounterViewModel();
    vm.increment();
    expect(vm.count, 1);
  });

  test('加载用户数据', () async {
    final mockRepo = MockUserRepository();
    when(mockRepo.getUser()).thenAnswer((_) async => testUser);

    final vm = ProfileViewModel(mockRepo);
    await vm.load();

    expect(vm.state.user, testUser);
    expect(vm.state.isLoading, false);
  });
}
```

---

### 用 Mock 测试 Widget

使用 `setProxy` 将真实 ViewModel 替换为 mock：

```dart
testWidgets('显示加载指示器', (tester) async {
  final mockVM = MockProfileViewModel();
  when(mockVM.state).thenReturn(ProfileState(isLoading: true));

  // 用 mock 替换真实 ViewModel
  profileProvider.setProxy(ViewModelProvider(builder: () => mockVM));

  await tester.pumpWidget(MyApp());
  expect(find.byType(CircularProgressIndicator), findsOneWidget);
});
```

**别忘了清理**：

```dart
tearDown(() {
  profileProvider.clearProxy();
});
```

---

### 测试使用其他 ViewModels 的 ViewModel

当你的 ViewModel 内部使用 `vef` 时，创建测试用的 Vef 上下文：

```dart
class TestVef with Vef {}

void main() {
  test('CartViewModel 使用 UserViewModel', () {
    final testVef = TestVef();

    // Mock 依赖
    final mockUserVM = MockUserViewModel();
    when(mockUserVM.user).thenReturn(testUser);
    userProvider.setProxy(ViewModelProvider(builder: () => mockUserVM));

    // 通过 Vef 上下文创建 ViewModel
    final cartVM = testVef.read(cartProvider);
    cartVM.checkout();

    verify(mockUserVM.user).called(1);

    testVef.dispose();
  });
}
```

---

## ⚠️ 常见坑点

### ❌ 在构造函数中访问 `vef`

**问题**：`vef` 只在 `onCreate` 调用后才可用。

```dart
// ❌ 错误
class BadViewModel with ViewModel {
  BadViewModel() {
    final auth = vef.read(authProvider);  // 错误：vef 还未就绪！
  }
}

// ✅ 正确
class GoodViewModel with ViewModel {
  @override
  void onCreate() {
    super.onCreate();
    final auth = vef.read(authProvider);  // OK：vef 已就绪
  }
}
```

---

### ❌ 忘记通知监听者

**问题**：状态变化后 UI 不更新。

```dart
// ❌ 错误
class BadViewModel with ViewModel {
  int count = 0;
  void increment() {
    count++;  // UI 不会更新！
  }
}

// ✅ 正确 - 方式 1
class GoodViewModel with ViewModel {
  int count = 0;
  void increment() {
    count++;
    notifyListeners();  // 手动通知
  }
}

// ✅ 正确 - 方式 2（推荐）
class BetterViewModel with ViewModel {
  int count = 0;
  void increment() {
    update(() => count++);  // 自动通知
  }
}
```

---

### ❌ 在回调中使用 `vef.watch`

**问题**：不必要的 widget 重建。

```dart
// ❌ 错误 - 在回调中 watch
FloatingActionButton(
  onPressed: () {
    vef.watch(counterProvider).increment();  // 浪费性能！
  },
)

// ✅ 正确 - 在回调中 read
FloatingActionButton(
  onPressed: () {
    vef.read(counterProvider).increment();  // 高效！
  },
)
```

---

### ❌ 直接修改状态对象

**问题**：`StateViewModel` 无法检测到对同一对象的修改。

```dart
// ❌ 错误
class BadViewModel extends StateViewModel<MyState> {
  void update() {
    state.count++;  // 修改同一对象
    setState(state);  // 不会触发重建！
  }
}

// ✅ 正确
class GoodViewModel extends StateViewModel<MyState> {
  void update() {
    setState(state.copyWith(count: state.count + 1));  // 新对象
  }
}
```

---

## 📊 架构决策矩阵

选择模式时参考这个指南：

| 场景 | 模式 | 原因 |
|------|------|-----|
| 简单计数器/开关 | `with ViewModel` + 可变状态 | 开销最小 |
| 复杂状态 + 验证 | `StateViewModel<T>` + Freezed | 类型安全、不可变 |
| 全局 auth/设置 | `with ViewModel` + `aliveForever: true` | 单例模式 |
| 数据获取 | Repository `with ViewModel` | 干净地访问全局状态 |
| 多步表单 | `StateViewModel<T>` 分步状态 | 不可变追踪进度 |
| 实时更新 | `with ViewModel` + Stream 监听 | 响应式数据流 |

---

## 🎯 快速参考

### 分层总结

```
┌─────────────────────────────────────────────┐
│  表现层（Widgets）                           │
│  ✓ ViewModelStateMixin                      │
│  ✓ build() 里用 vef.watch()                 │
│  ✓ 回调里用 vef.read()                      │
└──────────────────┬──────────────────────────┘
                   │
┌──────────────────▼──────────────────────────┐
│  领域层（ViewModels）                        │
│  ✓ with ViewModel 或 extends StateViewModel │
│  ✓ 业务逻辑 & 状态管理                       │
│  ✓ 协调 repositories                        │
└──────────────────┬──────────────────────────┘
                   │
┌──────────────────▼──────────────────────────┐
│  数据层（Repositories）                      │
│  ✓ with ViewModel                           │
│  ✓ API 调用、本地存储                        │
│  ✓ 通过 vef.read() 访问全局状态              │
└─────────────────────────────────────────────┘
```

---


*本指南是一个持续更新的文档。有更好的模式？欢迎提交 PR！* 🚀
