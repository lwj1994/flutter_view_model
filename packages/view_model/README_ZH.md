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

## 😫 痛点在哪里？

在 Flutter 开发中，状态管理总是让人头秃：
1.  **样板代码多到哭**：为了把状态传递给 Widget，你得写一堆 Provider（比如 `BlocProvider`、`ChangeNotifierProvider`），心累！
2.  **Context 地狱**：业务逻辑离不开 `BuildContext`，想在逻辑层互相调用？难！想测试？更难！UI 一改，逻辑全挂。

## 💡 解决方案来了！

**view_model** 就是为了解决这些痛点而生的！它把业务逻辑和 Widget 树完全解耦，真的超好用！

*   **默认隔离**：不像 Riverpod 那样全是全局状态，ViewModel 默认是**不共享**的。每个 Widget 都有自己独立的实例，再也不用担心状态污染啦！🛡️
*   **显式共享**：只有当你真的想共享时，通过 `key` 就能轻松实现。🔑
*   **零样板代码**：不用在 Widget 树顶层手动套 Provider，随用随取！✨
*   **告别 Context**：ViewModel 之间互相调用完全不需要 Context，清爽！🍃
*   **自动生命周期**：用的时候自动创建，不用了自动销毁，内存管理全自动！♻️

## 📦 安装搞起

```yaml
dependencies:
  view_model: ^latest_version

dev_dependencies:
  build_runner: ^latest_version
  view_model_generator: ^latest_version # 强烈推荐！
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

### 1. 数据访问 (`vef`) 🗝️

`vef` (ViewModel Element Factory) 是你操作 ViewModel 的神器：

| 方法 | 用法 |
| :--- | :--- |
| `vef.watch(provider)` | **获取 + 监听**。返回实例并订阅更新（触发重建）。在 `build()` 或 `initState()` 里放心用！ |
| `vef.read(provider)` | **仅获取**。返回实例但不订阅。**不会**触发重建。在回调（如 `onPressed`）里用它！ |
| `vef.listen(provider)` | **仅监听**。订阅变化来处理副作用（比如弹窗），不重建 UI。会自动释放哦。 |

### 2. 不可变状态 (`StateViewModel`) 🔒

对于复杂状态，不可变对象 (Immutable) 才是 YYDS！`StateViewModel` 专门为此设计。

```dart
// 1. 状态类
class UserState {
  final String name;
  final bool isLoading;
  UserState({this.name = '', this.isLoading = false});
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
final vm = vef.watch(userProvider(123)); // 传参只需一步
```

### 4. 实例共享 (Keys) 🔗

**默认行为：隔离**
当你调用 `vef.watch(provider)`，你拿到的是这个 Widget **独享**的全新实例。别的 Widget 用同一个 provider，拿到的是另一个实例。

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
    // Key 一样，拿到的就是同一个实例！
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
    *   `listen`：内部由于也拿到了实例，所以也算持有引用。
3.  **销毁**：Widget 销毁时，引用 -1。当引用归零，ViewModel 自动 `dispose()`。👋

> **例外 (Keep Alive)**：如果你在 provider 里设置了 `aliveForever: true`，那它就**永远不会**自动销毁，哪怕引用归零。这就变成全局单例啦！

### 6. 长生不老 (全局状态)

默认情况下，ViewModel 无人使用时会自动销毁。但有些 ViewModel 需要“长生不老”（比如用户会话、应用设置）。

你可以通过设置 `aliveForever: true` 来实现。**强烈建议同时指定 `key`**，以便在全局范围内唯一标识和查找该实例。

#### 手动定义

```dart
final appSettingsProvider = ViewModelProvider<AppSettingsViewModel>(
  builder: () => AppSettingsViewModel(),
  key: () => 'app_settings', // 指定一个全局 key
  aliveForever: true, // 这个实例永远不会被销毁
);
```

#### 使用生成器 (推荐)

```dart
@GenProvider(key: 'app_settings', aliveForever: true)
class AppSettingsViewModel extends ViewModel {}
```

注意：即使 `aliveForever` 为 true，ViewModel 依然是 **懒加载** 的。只有第一次访问时才会创建。

### 7. 代码生成 (强烈推荐) 🤖

手写 `ViewModelProvider` 太麻烦？用 `@genProvider` 解放双手！

```dart
@genProvider
class MyViewModel extends ViewModel {}
```

运行 `dart run build_runner build`，Provider 自动生成！
详情看这里 👉 [view_model_generator](../view_model_generator/README_ZH.md)

## 🧪 测试

用 `setProxy` 就能轻松 Mock 任何 ViewModel！

```dart
testWidgets('我的测试', (tester) async {
  final mockVM = MockCounterViewModel();
  
  // 用 Mock 替换真实实现
  counterProvider.setProxy(
    ViewModelProvider(builder: () => mockVM)
  );

  await tester.pumpWidget(MyApp());
  // ...
});
```

## 🔧 全局配置

在 `main()` 里可以配置全局行为。

```dart
void main() {
  ViewModel.initialize(
    config: ViewModelConfig(
      isLoggingEnabled: true, // 开启日志大法
    ),
    // 添加全局导航/生命周期观察者
    // lifecycles: [], 
  );
  runApp(MyApp());
}
```

## 📄 License

MIT License - 详见 [LICENSE](./LICENSE) 文件。
