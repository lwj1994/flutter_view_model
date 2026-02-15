# view_model

[![pub package](https://img.shields.io/pub/v/view_model.svg)](https://pub.dev/packages/view_model)

[English](./README.md)

**一切皆 ViewModel。**

这是一个为 Flutter 量身定制的状态管理框架。它基于“类型键（Type-keyed）实例注册表”构建，并自带“自动引用计数”的生命周期管理系统。无需繁琐的初始化，真正做到**按需创建，自动销毁**。

```yaml
dependencies:
  view_model: ^15.0.0-dev.5
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
- [💤 智能 暂停 / 恢复 机制](#-智能-暂停--恢复-机制)
- [♻️ 生命周期细节与资源回收](#-生命周期细节与资源回收)
- [🛠️ 全局配置与调试](#-全局配置与调试)
- [🧪 测试方案](#-测试方案)
- [🤖 代码自动生成](#-代码自动生成)
- [🔍 DevTools 视觉化窗口](#-devtools-视觉化窗口)

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
  late final vm = viewModelBinding.watch(counterSpec);

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

---

## 🔗 viewModelBinding 核心接口

当你拥有了 `viewModelBinding` 访问器，你就拥有了以下超能力：

| 方法 | 使用场景 | 特点 |
| :--- | :--- | :--- |
| **`watch(spec)`** | 在 Widget 的 `build` 或逻辑中 | **响应式**：VM 变化会触发 UI 刷新。若 VM 不存在则创建。 |
| **`read(spec)`** | 事件回调、只需调用方法时 | **非响应式**：仅读取，不监听。若 VM 不存在则创建。 |
| **`watchCached(key/tag)`** | 寻找现有的单例或共享 VM | 如果缓存里没找到，它会抛出异常。 |
| **`listenStateSelect(...)`**| 针对性监听某个字段 | 例如：只有 `user.age` 变了才弹窗，别的字段变了不理。 |
| **`recycle(vm)`** | 强制销毁重来 | 比如：退出登录时，一键回收所有用户相关的 VM。 |

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

## 🌏 关于本地化支持

本项目提供极其稳定的兼容支持：
*   `vef` 曾经是我们的核心概念名，虽然现在已更名为 `viewModelBinding`，但目前的版本依然支持 `vef` 变量及 `with Vef`。
*   `ViewModelProvider` 现在改名为 `ViewModelSpec`，我们依然为你留了兼容别名。

---

## 📜 开源协议

本项目采用 [Apache License 2.0](LICENSE)。

如果你觉得好用，请给个 **Star** 🌟，这是对作者最大的支持！
