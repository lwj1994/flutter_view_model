# view_model：状态管理、依赖注入与模块架构

| `view_model` | `view_model_annotation` | `view_model_generator` | 覆盖率 |
| :---: | :---: | :---: | :---: |
| [![view_model 版本](https://img.shields.io/pub/v/view_model.svg)](https://pub.dev/packages/view_model) | [![view_model_annotation 版本](https://img.shields.io/pub/v/view_model_annotation.svg)](https://pub.dev/packages/view_model_annotation) | [![view_model_generator 版本](https://img.shields.io/pub/v/view_model_generator.svg)](https://pub.dev/packages/view_model_generator) | [![codecov](https://codecov.io/gh/lwj1994/flutter_view_model/branch/main/graph/badge.svg)](https://app.codecov.io/gh/lwj1994/flutter_view_model) |

[English](./README.md)

**不只是状态管理。view_model 同时是一套面向 Flutter 的依赖注入、功能模块组合与自动生命周期管理架构。**

每个功能单元——页面状态、服务、仓储、协调器或领域能力——都可以是
ViewModel。ViewModel 之间通过 `viewModelBinding` 相互依赖注入与组合，
由 `ViewModelBinding` 在 getter 被实际访问时按需解析对应节点、在作用域内
复用实例，并自动完成回收；无需依赖全局单例。

```yaml
dependencies:
  view_model: ^1.0.0
```

## 🤖 Skill 安装

```bash
npx skills add https://github.com/lwj1994/flutter_view_model --skill view_model
```

---

## 📖 核心目录

- [🌟 为什么选择 view_model？](#-为什么选择-view_model)
- [🏗️ 三层架构设计](#️-三层架构设计)
- [🧩 核心武器：两大 Mixin](#-核心武器两大-mixin)
- [🚀 3 分钟快速上手](#-3-分钟快速上手)
- [📖 ViewModel 深度探索](#-viewmodel-深度探索)
- [⚙️ ViewModelSpec：声明式定义](#-viewmodelspec声明式定义)
- [🎨 Widget 集成指北](#-widget-集成指北)
- [🔗 viewModelBinding 核心接口](#-viewmodelbinding-核心接口)
- [🤝 实例共享与共享策略](#-实例共享与共享策略)
- [🏗️ 在任意非 Widget 类中使用](#️-在任意非-widget-类中使用)
- [🔄 ViewModel 间的强力联动](#-viewmodel-间的强力联动)
- [⚡ 细粒度更新（性能优化）](#-细粒度更新性能优化)
- [⚠️ ObservableValue 迁移](#️-observablevalue-迁移)
- [💤 智能 暂停 / 恢复 机制](#-智能-暂停--恢复-机制)
- [♻️ 生命周期细节与资源回收](#-生命周期细节与资源回收)
- [🛠️ 全局配置与调试](#-全局配置与调试)
- [🧪 测试方案](#-测试方案)
- [🤖 代码自动生成](#-代码自动生成)
- [🔍 DevTools 视觉化窗口](#-devtools-视觉化窗口)
- [view_model vs riverpod](#view_model-vs-riverpod)

---

## 🌟 为什么选择 view_model？

在 Flutter 状态管理的丛林里，你可能被 `Provider` 的 `context` 限制搞晕，或者被 `Riverpod` 复杂的 Provider 依赖图劝退。**view_model 的设计哲学是：直觉化、Dart 原生感、零痛苦。**

*   **真正的自动生命周期**：ViewModel 的存活完全取决于是否有 Widget 在用它。没人用了？自动销毁，一行代码都不用写。
*   **跨越 BuildContext 的自由**：不仅仅在 Widget 里，在后台服务、启动逻辑、纯 Dart 类中都能享用同样的 ViewModel 管理逻辑。
*   **自带“防卡顿”光环**：当页面进入后台或被上层路由覆盖时，系统会自动暂停通知，仅在页面恢复时触发一次追赶式刷新。
*   **极致的代码生成**：配合 `@GenSpec` 注解，样板代码归零。

---



## 🏗️ 三层架构设计

为了实现极致的灵活性，我们将系统拆分为三层：

1.  **消费者层 (Widget/Consumer)**: 提供 `ViewModelStateMixin`、`ViewModelBuilder` 等贴心的工具。
2.  **绑定层 (ViewModelBinding)**: 核心桥梁。它负责记录谁（哪个 BindingID）在使用哪个 ViewModel。它还掌管着 Zone 依赖注入和 暂停/恢复 状态。
3.  **实例管理层 (InstanceManager)**: 一个高效的底盘。它维护着一个实例池，并根据引用计数（BindingIDs 是否为空）决定实例的死活。

---

## 🧩 核心武器：两大 Mixin

这是本库的灵魂。只要能掌握这两个 Mixin，你就掌握了全部。

### 1. `with ViewModel` — 赋予“生命”
将它混入任意类，这个类就变成了**受管实例**。它拥有生命周期钩子（`onCreate`, `onDispose` 等），能够发射通知，还能通过 `viewModelBinding` 直接读取其他依赖项。

```dart
class UserRepository with ViewModel { /* 业务逻辑 */ }
```

### 2. `with ViewModelBinding` — 获取“力量”
将它混入类（不限 Widget），这个类就变成了**管理员**。它拥有了访问注册表的能力。你可以用它来 `watch` 或 `read` 任何 ViewModel。`ViewModelStateMixin` 本质上就是它的一个 Widget 封装版。

```dart
class AppBootstrap with ViewModelBinding {
  Future<void> init() async {
    // 跨越 context 自由读取
    await viewModelBinding.read(configSpec).load();
  }
}
```

---

## 🚀 3 分钟快速上手

```dart
import 'package:view_model/view_model.dart';

// 1. 写逻辑
class CounterViewModel with ViewModel {
  int count = 0;
  void increment() => update(() => count++); // update 会自动帮你触发 UI 刷新
}

// 2. 定规格 (Spec)
final counterSpec = ViewModelSpec<CounterViewModel>(
  builder: () => CounterViewModel(),
);

// 3. 混入 Mixin 即可使用
class CounterPage extends StatefulWidget {
  @override
  State<CounterPage> createState() => _CounterPageState();
}

class _CounterPageState extends State<CounterPage> with ViewModelStateMixin {
  // watch 会建立连接：ViewModel 变了，当前 Widget 自动刷新
  CounterViewModel get vm => viewModelBinding.watch(counterSpec);

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: vm.increment,
      child: Text('Count: ${vm.count}'),
    );
  }
}
```

---

## 📖 ViewModel 深度探索

### StateViewModel（强状态版）
如果你追求不可变状态（配合 `Freezed` 简直完美），它是你的不二之选。它能记录 `previousState`，并支持字段级的差异化监听（`listenStateSelect`）。

做字段级更新时，建议用 `read` 读取 ViewModel，再交给
`listenStateSelect` / `StateViewModelValueWatcher` 驱动更新；不要再对同一
个 ViewModel 额外使用 `watch`，否则会把整份 ViewModel 的宽范围监听也挂上。

```dart
class UserViewModel extends StateViewModel<UserState> {
  UserViewModel() : super(state: const UserState());

  void updateName(String name) {
    setState(state.copyWith(name: name)); // 自动触发 equals 比较
  }
}
```

### 资源快捷回收
在构造函数里使用 `addDispose()`，确保资源不遗忘：

```dart
StreamViewModel() {
  final sub = stream.listen((_) => notifyListeners());
  addDispose(() => sub.cancel()); // 跟着 VM 一起死，优雅！
}
```

## 🔄 ViewModel 间的强力联动

ViewModel 内部的依赖统一通过非缓存 getter 获取。getter 每次都会经由
`refHandler` 当前选中的 owner binding（首个仍存在的 owner，不一定是调用方
root）解析，但同一 binding 内仍会复用同一个受管实例：

```dart
class OrderViewModel with ViewModel {
  CartViewModel get cart => viewModelBinding.read(cartSpec);
  UserViewModel get user => viewModelBinding.read(userSpec);

  double get total => cart.items.fold(0, (sum, item) => sum + item.price);
}
```

优先 getter，不要用 `late final`、构造时缓存或 `??=` 持有嵌套 ViewModel。
root binding 只负责释放它实际解析过的实例；getter 声明本身不会创建任何
对象。

> **共享父模块边界：** 一个带 key 的父 ViewModel 可以被多个 root binding
> 共同持有，但父模块解析出的子依赖不会自动绑定到所有 root。解析子依赖的
> root 被销毁后，父模块可能仍存活而子模块已经销毁。非缓存 getter 能避免
> 继续持有已销毁对象，并在下次访问时通过 `refHandler` 新选中的 owner 重新
> 解析；但子模块可能被重新创建，原状态不保证连续。需要连续共享状态时，
> 优先使用不带 key 的复合父模块，并让每个 root 都解析带 key 的共享叶子
> 模块；也可以使用明确的应用级 binding owner。

## ⚠️ ObservableValue 迁移

`ObservableValue`、`ObserverBuilder`、`ObserverBuilder2` 和
`ObserverBuilder3` 已弃用，计划在 2.0.0 移除。它们只是隐藏
`StateViewModel` 的便捷封装，并不是核心状态管理能力；1.x 期间仍会保留，
供现有项目迁移。

Widget 内部的局部响应式值，请改用 Flutter 自带的 `ValueNotifier` 和
`ValueListenableBuilder`，并由其持有者负责 `dispose`：

```dart
class ThemeToggle extends StatefulWidget {
  const ThemeToggle({super.key});

  @override
  State<ThemeToggle> createState() => _ThemeToggleState();
}

class _ThemeToggleState extends State<ThemeToggle> {
  final ValueNotifier<bool> _isDarkMode = ValueNotifier<bool>(false);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _isDarkMode,
      builder: (context, isDarkMode, child) {
        return IconButton(
          icon: Icon(isDarkMode ? Icons.dark_mode : Icons.light_mode),
          onPressed: () => _isDarkMode.value = !isDarkMode,
        );
      },
    );
  }

  @override
  void dispose() {
    _isDarkMode.dispose();
    super.dispose();
  }
}
```

需要 view_model 自动生命周期管理时，请显式使用 `StateViewModel` 和
`ViewModelSpec`。下面通过带 key 的非 Widget binding owner 持有状态，因此
生产者可以在观察 Widget 挂载前或卸载期间继续读取和更新：

```dart
class ThemeModeViewModel extends StateViewModel<bool> {
  ThemeModeViewModel() : super(state: false);

  void setDarkMode(bool value) => setState(value);
}

final themeModeSpec = ViewModelSpec<ThemeModeViewModel>(
  builder: ThemeModeViewModel.new,
  key: 'theme-dark',
);

class ThemeModeOwner with ViewModelBinding {
  ThemeModeViewModel get themeMode =>
      viewModelBinding.read(themeModeSpec);

  void setDarkMode(bool value) => themeMode.setDarkMode(value);
}

class ThemeModeExample extends StatefulWidget {
  const ThemeModeExample({super.key});

  @override
  State<ThemeModeExample> createState() => _ThemeModeExampleState();
}

class _ThemeModeExampleState extends State<ThemeModeExample> {
  final ThemeModeOwner _owner = ThemeModeOwner();

  @override
  void initState() {
    super.initState();
    // 在观察子 Widget 挂载前创建并更新实例。
    _owner.setDarkMode(true);
  }

  @override
  Widget build(BuildContext context) => const ThemeModeButton();

  @override
  void dispose() {
    _owner.dispose();
    super.dispose();
  }
}

class ThemeModeButton extends StatefulWidget {
  const ThemeModeButton({super.key});

  @override
  State<ThemeModeButton> createState() => _ThemeModeButtonState();
}

class _ThemeModeButtonState extends State<ThemeModeButton>
    with ViewModelStateMixin {
  ThemeModeViewModel get themeMode =>
      viewModelBinding.watch(themeModeSpec);

  @override
  Widget build(BuildContext context) {
    final viewModel = themeMode;
    return IconButton(
      icon: Icon(viewModel.state ? Icons.dark_mode : Icons.light_mode),
      onPressed: () => viewModel.setDarkMode(!viewModel.state),
    );
  }
}
```

`ThemeModeExample` 完整展示了 owner 边界：在 `ThemeModeButton` 挂载前
更新状态、观察子 Widget 不存在时继续持有状态，并在作用域结束时释放非
Widget owner。应用、服务或启动作用域也遵循同一模式。这里的 key 用于跨
binding 共享；同一 binding 内要区分多个同 `T` 实例时也需要不同 key。key
本身不会保活，也不能替代 owner。只有明确需要进程级常驻并接受显式
recycle 或进程结束清理时，才使用 `aliveForever`。

迁移 `ObserverBuilder2` 或 `ObserverBuilder3` 时，优先把相关值合并为一个
明确的状态对象，避免继续用多个独立可观察值拼装业务状态。

---

## 🔗 viewModelBinding 核心接口

当你拥有了 `viewModelBinding` 访问器，你就拥有了以下超能力：

| 方法 | 使用场景 | 特点 |
| :--- | :--- | :--- |
| **`watch(spec)`** | 在 Widget 的 `build` 或逻辑中 | **响应式**：VM 变化会触发 UI 刷新。若 VM 不存在则创建。 |
| **`read(spec)`** | 事件回调、只需调用方法时 | **非响应式**：仅读取，不监听。若 VM 不存在则创建。 |
| **`watchCached(key/tag)`** | 寻找现有的单例或共享 VM | 如果缓存里没找到，它会抛出异常。 |
| **`readCached(key/tag)`** | 读取现有缓存但不触发刷新 | 只查找已有实例，不创建；会参与 binding 生命周期，但不响应 `notifyListeners()`。 |
| **`watchCachesByTag(tag)`** | 按 tag 批量响应式获取 VM | 批量版 `watch`：会 `bind`、响应 `notifyListeners()`，也会感知 recreate/dispose。 |
| **`readCachesByTag(tag)`** | 按 tag 批量读取已有 VM | 批量版 `read`：会 `bind`、感知 recreate/dispose，并参与 dispose 清理，但不响应 `notifyListeners()`。 |
| **`listenStateSelect(...)`**| 针对性监听某个字段 | 例如：只有 `user.age` 变了才弹窗，别的字段变了不理。 |
| **`recycle(vm)`** | 强制销毁重来 | 比如：退出登录时，一键回收所有用户相关的 VM。 |

补充说明：

- `watch*` 和 `read*` 都会建立 binding，都会影响实例生命周期；差别主要在于是否监听 ViewModel 自身的变化。
- 做字段级更新时，优先用 `read` 拿到 ViewModel，再交给 `listenStateSelect` 或 `StateViewModelValueWatcher` 驱动更新；不要再对同一个 ViewModel 额外 `watch`。
- 实例身份由“解析时使用的泛型 ViewModel 类型 `T` + effective key”共同
  决定；builder 返回对象的运行时具体类型不参与身份，`tag` 也只用于分组
  检索。factory 的 `key()` 返回 `null` 时，同一 binding 内同一 `T` 只会
  复用一个实例，不同 binding 默认隔离。跨 binding 共享、同一 binding 内
  区分多个同 `T` 实例，
  或需要稳定的 keyed cached lookup 时，应显式设置 key。key 本身不负责
  保活；`aliveForever` 只跳过引用归零时的自动回收，显式 `recycle` 仍可销毁。

---

## 💤 智能 暂停 / 恢复 机制

这是 `view_model` 的独门绝技。
*   **不浪费一分性能**：当你的页面处于“不可见”状态（被覆盖、Tab 被切走、应用退后台），哪怕 ViewModel 疯狂更新，你的 Widget 也**完全不会 rebuild**。
*   **丝滑追赶**：当你重新看到页面的一瞬间，系统会帮你做一次补报刷新，确保数据是最新的。

> **提示**：为了让路由感知生效，别忘了在 `MaterialApp` 里加上 `ViewModel.routeObserver`。

---

## 🤖 代码自动生成

厌倦了手写 `ViewModelSpec`？没关系，交给 `view_model_generator`。

```dart
@GenSpec(key: 'global_counter', aliveForever: true) // 一键定义单例
class CounterViewModel with ViewModel { ... }
```

一行命令，生成的 Spec 自动帮你搞定参数注入和单例配置。

---

## 🔍 DevTools 视觉化窗口

我们为你准备了强大的 **DevTools 扩展**。在调试模式下，打开 Flutter DevTools：
*   **可视化依赖图**：一眼看清哪个 Widget 绑定了哪个 ViewModel，谁又依赖了谁。
*   **状态实时监控**：在不需要打印日志的情况下，直接在浏览器里检视所有存活实例的数据。

---

## view_model vs riverpod

两者底层都基于“中央注册表 + 依赖注入”的思想，但设计哲学、API 风格、实例管理机制不同。以下对比基于默认配置与常见用法（如单根 `ProviderScope`），仅讨论状态管理核心：状态建模、依赖派生、实例作用域与生命周期，不将 `Mutations` / `Automatic retry` / `Offline persistence` 作为主要评价项。

### 1. 核心设计哲学

* Riverpod：一切皆是全局响应式节点（Functional & Declarative）
> 核心是构建一个全局的有向无环图（DAG）。状态默认是全局单例的（挂载在 ProviderScope 上），强调状态与状态之间的纯函数推导（Derived State）。它非常排斥将状态与特定的 Widget 实例强绑定。
* view_model：经典的组件级视图模型（OOP & Lifecycle-bound）
> 核心是基于引用计数（Reference Counting）的实例管理。它通过 Mixin 将能力注入到任意类中，默认情况下，状态是局部作用域的（与绑定的 Widget 生命周期共存亡）。它更像 Android 的 ViewModel 或传统客户端开发中的 MVVM 模式。

### 2. 代码风格与实现方式

| 维度 | Riverpod 3.x | view_model 1.0.0 |
| :--- | :--- | :--- |
| **类实现方式** | 继承/codegen 为主（`Notifier`/`AsyncNotifier`/`@riverpod`） | **纯 mixin 方式**（`class X with ViewModel`） |
| **优点** | Provider 组合与响应式派生能力强 | 零侵入、可多 mixin 叠加、任意类可直接成为 ViewModel |
| **watch/read 位置** | 在 `Consumer` 的 `build` 中常用 `ref.watch(...)`；在 Provider/Notifier 的 `build` 中也可 `ref.watch(...)`；在 Widget 中若需在 `build` 外监听，可用 `WidgetRef.listenManual(...)` | 可通过 getter 暴露（如 `MyViewModel get vm => viewModelBinding.watch(...)`），不强制写在 `build` 内 |

**view_model 示例（getter 声明）**：

```dart
class _MyPageState extends State<MyPage> with ViewModelStateMixin {
  CounterViewModel get counterVM => viewModelBinding.watch(counterSpec);
  UserViewModel get userVM => viewModelBinding.watch(userSpec);

  @override
  Widget build(BuildContext context) {
    return Text('${counterVM.count}'); // 自动响应式
  }
}
```

### 3. 实例获取与作用域（核心差异）

- **Riverpod**：实例按 `ProviderContainer` 隔离。常见项目只有一个根 `ProviderScope`，因此同一 Provider 在整个 App 内通常共享一份状态；需要隔离时通过局部 `ProviderScope`/override/family 控制。
- **view_model**：默认是“每个 binding、每个解析类型参数 `T` 一个实例”。同一 `ViewModelBinding` 内对同一 `T` 多次 `watch/read` 会复用实例，不同页面（不同 binding）默认隔离。跨 binding 共享或在同一 binding 内区分多个同 `T` 实例时显式声明 key：

```dart
final globalAuthSpec = ViewModelSpec<AuthViewModel>(
  builder: () => AuthViewModel(),
  key: 'global-auth',
  aliveForever: true, // 可选：引用归零时仍保留，可显式 recycle
);
```


---
