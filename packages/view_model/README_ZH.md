<p align="center">
  <img src="https://lwjlol-images.oss-cn-beijing.aliyuncs.com/logo.png" alt="ViewModel Logo" height="96" />
</p>

# ✨ view_model：轻量级 Flutter 状态管理

> **超轻量（仅需 `with`）｜零侵入性｜告别 BuildContext 地狱**
>
> 只有 ~6K 行代码，却能让你的架构脱胎换骨 🚀

| Package | Version |
| :--- | :--- |
| **view_model** | [![Pub Version](https://img.shields.io/pub/v/view_model)](https://img.shields.io/pub/v/view_model) |
| **view_model_annotation** | [![Pub Version](https://img.shields.io/pub/v/view_model_annotation)](https://img.shields.io/pub/v/view_model_annotation) |
| **view_model_generator** | [![Pub Version](https://img.shields.io/pub/v/view_model_generator)](https://img.shields.io/pub/v/view_model_generator) |

[![Codecov](https://img.shields.io/codecov/c/github/lwj1994/flutter_view_model/main)](https://app.codecov.io/gh/lwj1994/flutter_view_model/tree/main)

[更新日志](https://github.com/lwj1994/flutter_view_model/blob/main/packages/view_model/CHANGELOG.md) | [English Doc](README.md) | [架构最佳实践](ARCHITECTURE_GUIDE_ZH.md)

---

## 💡 为什么选择 view_model？

### ✨ 三大核心优势

#### 🪶 **超轻量 = 零负担**
- **代码量超少**：核心仅 ~6K 行，3 个依赖（flutter + meta + stack_trace）
- **零配置启动**：无需包裹根组件，无需全局初始化
- **按需创建**：ViewModels 只在需要时才创建，用完自动销毁

#### 🎯 **低侵入性 = 改动最小**
- **只需 `with`**：给 State 加一个 `with ViewModelStateMixin` 就完事儿
- **不改现有代码**：兼容任何 Flutter 代码，随时可接入
- **纯 Dart Mixin**：利用 Dart 3 mixin 特性，零继承污染

#### 🌈 **自由度爆表**
- **随处可访问**：Widget、Repository、Service 都能直接用 ViewModel，不需要 `BuildContext`
- **自动内存管理**：引用计数 + 自动销毁，再也不担心内存泄漏
- **想共享就共享**：需要单例？加个 `key`。需要隔离？啥也不加。就是这么简单！

---

## 📦 安装

```yaml
dependencies:
  view_model: ^latest_version

dev_dependencies:
  build_runner: ^latest_version
  view_model_generator: ^latest_version  # 强烈推荐！省超多代码
```

---

## 🚀 三步上手（比你想的简单）

### 步骤 1️⃣：写业务逻辑

**只需 `with ViewModel`**（没错，就这么简单）：

```dart
class CounterViewModel with ViewModel {
  int count = 0;

  void increment() {
    update(() => count++);  // 自动通知 UI 刷新
  }
}
```

**为什么用 `with` 而不是 `extends`？**
因为 Dart 的 mixin 支持组合多个能力，比继承更灵活，完全不污染你的类结构！

---

### 步骤 2️⃣：注册 Provider

```dart
final counterProvider = ViewModelProvider<CounterViewModel>(
  builder: () => CounterViewModel(),
);
```

**偷懒秘籍**：用 `view_model_generator` 可以跳过这步，加个注解就自动生成 🎉

---

### 步骤 3️⃣：在 Widget 中使用

**只加一个 mixin，就能获得超能力**：

```dart
class CounterPage extends StatefulWidget {
  @override
  State<CounterPage> createState() => _CounterPageState();
}

class _CounterPageState extends State<CounterPage>
    with ViewModelStateMixin {  // 👈 就加这一行！

  @override
  Widget build(BuildContext context) {
    final vm = vef.watch(counterProvider);  // 自动监听变化

    return Scaffold(
      body: Center(child: Text('${vm.count}')),
      floatingActionButton: FloatingActionButton(
        onPressed: vm.increment,
        child: Icon(Icons.add),
      ),
    );
  }
}
```

**对比一下侵入性**：

| 方案 | 需要改的地方 | 根组件包裹 | BuildContext 依赖 |
|------|------------|-----------|-----------------|
| **view_model** | ✅ 只加 mixin | ❌ 不需要 | ❌ 不需要 |
| Provider | ⚠️ InheritedWidget | ✅ 需要 | ✅ 需要 |
| Riverpod | ⚠️ ConsumerWidget | ✅ 需要 | ❌ 不需要 |
| GetX | ⚠️ 常用全局状态 | ❌ 不需要 | ❌ 不需要 |

---

## 🛠️ 核心功能

### 1️⃣ 万物皆可访问（Vef 魔法）

**`vef` 是什么？**
`Vef` = ViewModel Execution Framework，是一个可以加到**任何类**的 mixin。有了它，你就能在任何地方访问 ViewModel！

> 💡 **冷知识**：`ViewModelStateMixin` 的幕后功臣其实是 `WidgetVef` —— 一个专门为 Flutter 优化的 `Vef` 变体。这保证了无论你在 Widget、ViewModel 还是纯 Dart 类中，都能享受到一致的 API 体验！

#### 📱 在 Widget 里（自带）

```dart
class _MyPageState extends State<MyPage> with ViewModelStateMixin {
  @override
  Widget build(BuildContext context) {
    final vm = vef.watch(myProvider);  // 自动监听
    return Text(vm.data);
  }
}
```

#### 🧠 在 ViewModel 里（自带）

ViewModels 之间可以互相调用：

```dart
class CartViewModel with ViewModel {
  void checkout() {
    final userVM = vef.read(userProvider);  // 直接读取其他 VM
    processOrder(userVM.user);
  }
}
```

#### 🏗️ 在任意类里（自定义 Ref）

需要一个纯逻辑管理器？加个 `with Vef` 就行：

```dart
class StartupTaskRunner with Vef {
  Future<void> run() async {
    final authVM = vef.read(authProvider);
    await authVM.checkAuth();

    final configVM = vef.read(configProvider);
    await configVM.fetchRemoteConfig();
  }

  @override
  void dispose() {
    super.dispose();  // 自动清理所有依赖
  }
}
```

#### 🎯 快速参考：vef 方法

| 方法 | 特点 | 适用场景 |
| :--- | :--- | :--- |
| `vef.watch(provider)` | **响应式** | 在 `build()` 里用，数据变化时自动重建 |
| `vef.read(provider)` | **直接访问** | 在回调、事件处理或其他 ViewModel 里用 |
| `vef.listen(provider)` | **副作用监听** | 执行导航、弹窗等副作用操作 |
| `vef.watchCached(key:)` | **精准访问** | 通过 key 访问特定的共享实例 |
| `vef.readCached(key:)` | **缓存读取** | 读取特定共享实例但不监听 |
| `vef.listenState(provider)` | **状态监听** | 监听状态变化（获取前后值） |
| `vef.listenStateSelect(provider)` | **选择监听** | 仅当选定属性变化时触发 |

**传统 API 支持**：如果你更喜欢 `watchViewModel` 这种经典写法，放心用！底层已经升级到高性能 `vef` 引擎：

| 传统方法 | 现代写法 | 说明 |
| :--- | :--- | :--- |
| `watchViewModel` | `vef.watch` | 监听变化 + 自动重建 |
| `readViewModel` | `vef.read` | 直接读取，零开销 |
| `listenViewModel` | `vef.listen` | 监听变化不重建 |
| `watchCachedViewModel` | `vef.watchCached` | 监听缓存实例 |
| `readCachedViewModel` | `vef.readCached` | 读取缓存实例 |
| `listenViewModelState` | `vef.listenState` | 监听状态变化 |
| `listenViewModelStateSelect` | `vef.listenStateSelect` | 选择性监听状态 |

---

### 2️⃣ 不可变状态（StateViewModel）

喜欢不可变状态的开发者看这里！配合 [Freezed](https://pub.dev/packages/freezed) 效果更佳 ✨

```dart
class UserViewModel extends StateViewModel<UserState> {
  UserViewModel() : super(state: UserState());

  void loadUser() async {
    setState(state.copyWith(isLoading: true));
    // ... 加载数据 ...
    setState(state.copyWith(isLoading: false, name: 'Alice'));
  }
}
```

---

### 3️⃣ 参数传递（不装 DI）

**真心话时间**：Flutter 的很多"依赖注入"库其实是**服务定位器**（Service Locator）伪装的。真正的 DI 需要反射或强大的元编程，但 Flutter 禁用了反射。

我们选择**拥抱现实**——用清晰明确的参数系统：

```dart
final userProvider = ViewModelProvider.arg<UserViewModel, int>(
  builder: (int id) => UserViewModel(id),
);

// 使用：
final vm = vef.watch(userProvider(42));
```

简单、直接、可调试，不玩虚的！

---

### 4️⃣ 实例共享（Key 机制）

- **默认隔离**：每个 widget 有自己独立的 ViewModel 实例
- **共享实例**：给个 `key`，所有相同 key 的地方共享同一个实例

```dart
final productProvider = ViewModelProvider.arg<ProductViewModel, String>(
  builder: (id) => ProductViewModel(id),
  key: (id) => 'prod_$id',  // 相同 ID 共享实例
);
```

---

### 5️⃣ 自动生命周期 ♻️

**最爱的功能！完全不用操心内存管理：**

1. **创建**：第一次 `watch` 或 `read` 时自动创建
2. **保活**：只要有 widget 在用就一直存在
3. **销毁**：最后一个使用者卸载时自动清理

**需要全局单例？** 加上 `aliveForever: true`，适合 Auth、App Config 等：

```dart
final authProvider = ViewModelProvider(
  builder: () => AuthViewModel(),
  key: 'auth',
  aliveForever: true,  // 永不销毁
);
```

---

## 🏗️ 架构模式

在真实项目中，Repository、Service 都能用 `with ViewModel` 来协调其他 ViewModels，完全不需要传递 `BuildContext`：

```dart
class UserRepository with ViewModel {
  Future<User> fetchUser() async {
    final token = vef.read(authProvider).token;  // 直接读取
    return api.getUser(token);
  }
}
```

详细架构指南看这里：**[架构最佳实践](ARCHITECTURE_GUIDE_ZH.md)**

---

## 🧪 测试友好

Mock 超简单，不需要启动模拟器就能测试：

```dart
testWidgets('显示正确的用户数据', (tester) async {
  final mockVM = MockUserViewModel();
  userProvider.setProxy(ViewModelProvider(builder: () => mockVM));

  await tester.pumpWidget(MyApp());
  expect(find.text('Alice'), findsOneWidget);
});
```

---

## ⚙️ 全局配置

在 `main()` 里配置：

```dart
void main() {
  ViewModel.initialize(
    config: ViewModelConfig(
      isLoggingEnabled: true,
      onListenerError: (error, stack, context) {
         // 上报到 Crashlytics
      },
    ),
  );
  runApp(MyApp());
}
```

---

## 📊 轻量级证明

| 指标 | 数值 |
|------|------|
| 核心代码量 | ~6K 行（含注释） |
| 必需依赖 | 3 个（flutter、meta、stack_trace） |
| 需要的 mixin | 1 个（`ViewModelStateMixin`） |
| 需要包裹根组件 | ❌ 不需要 |
| 需要全局初始化 | ❌ 不需要（可选） |
| 性能开销 | 极低（引用计数 + Zone） |

---

## 📜 开源协议

MIT License - 随便用，放心用 💖

---

## 🎉 最后说两句

如果你也厌倦了：
- ❌ BuildContext 到处传
- ❌ 复杂的全局状态管理
- ❌ 动不动就内存泄漏
- ❌ 代码侵入性强

那就试试 **view_model** 吧！**轻量、简洁、优雅**，让你的代码重获新生 ✨

**记住**：只需要 `with`，一切都变得简单！

---

*Built with ❤️ for the Flutter community.*
