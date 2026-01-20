<p align="center">
  <img src="https://lwjlol-images.oss-cn-beijing.aliyuncs.com/logo.png" alt="ViewModel Logo" height="96" />
</p>

# view_model：Flutter 原生风格状态管理

契合 Flutter OOP 和 Widget 风格。低侵入、VM 可访问 VM、任何类均可作为 ViewModel、支持细粒度更新。专为 Flutter 打造。

| Package | Version |
| :--- | :--- |
| **view_model** | [![Pub Version](https://img.shields.io/pub/v/view_model)](https://img.shields.io/pub/v/view_model) |
| **view_model_annotation** | [![Pub Version](https://img.shields.io/pub/v/view_model_annotation)](https://img.shields.io/pub/v/view_model_annotation) |
| **view_model_generator** | [![Pub Version](https://img.shields.io/pub/v/view_model_generator)](https://img.shields.io/pub/v/view_model_generator) |

[![Codecov](https://img.shields.io/codecov/c/github/lwj1994/flutter_view_model/main)](https://app.codecov.io/gh/lwj1994/flutter_view_model/tree/main)

[更新日志](https://github.com/lwj1994/flutter_view_model/blob/main/packages/view_model/CHANGELOG.md) | [English Doc](README.md) | [架构最佳实践](ARCHITECTURE_GUIDE_ZH.md)

---

## Agent Skills
AI Agent 使用指南请参考 [Agent Skills](https://github.com/lwj1994/flutter_view_model/blob/main/skills/view_model/SKILL.md)。

## 为什么选择 view_model？
由习惯 MVVM 模式的移动端团队（Android, iOS, Flutter）开发。本库提供了 ViewModel 概念的原生 Flutter 实现，解决了现有状态管理方案的一些痛点。

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
使用 `ViewModel` mixin 编写业务逻辑。

```dart
class CounterViewModel with ViewModel {
  int count = 0;

  void increment() {
    update(() => count++); // 通知监听者
  }
}
```

### 2. 注册 Provider
```dart
final counterProvider = ViewModelProvider<CounterViewModel>(
  builder: () => CounterViewModel(),
);
```
*提示：使用 `view_model_generator` 可自动生成 Provider。*

### 3. 在 Widget 中使用
给 State 类添加 `ViewModelStateMixin` 即可访问 `vef` API。

```dart
class _CounterPageState extends State<CounterPage> with ViewModelStateMixin {
  @override
  Widget build(BuildContext context) {
    // watch() 会自动监听变化
    final vm = vef.watch(counterProvider);

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
| `vef.listen` | 副作用监听 | 导航、弹窗通知 |
| `vef.listenState` | 状态监听 | 监控状态切换 |

#### 使用示例
- **Widget**: 使用 `ViewModelStateMixin`。
- **ViewModel**: 内置支持访问其他 ViewModel。
- **普通类**: 使用 `with Vef`。

```dart
class TaskRunner with Vef {
  void run() {
    final authVM = vef.read(authProvider);
    authVM.checkAuth();
  }
}
```

---

### 2. 暂停机制 (Pause Mechanism)
为了节省资源，`view_model` 会在 Widget 不可见时（如被其他页面遮挡、应用切后台、TabBar 中隐藏）自动延迟 UI 更新。

- **自动化**：`ViewModelStateMixin` 默认通过 `AppPauseProvider`、`PageRoutePauseProvider` 和 `TickerModePauseProvider` 处理。
- **延迟更新**：处于暂停状态时，ViewModel 的通知会被加入队列。只有当 Widget 重新变为可见时，才会触发单次重建。

---

### 3. 细粒度更新
通过只重建必要的部分来优化性能。

- **StateViewModelValueWatcher**：仅当 `StateViewModel` 的指定字段变化时重建。
- **ObservableValue & ObserverBuilder**：适用于独立、简单逻辑的响应式值。

| 方式 | 范围 | 适用场景 |
|----------|--------------|----------|
| `vef.watch` | 整个 widget | 简单场景 |
| `StateViewModelValueWatcher` | 选定字段 | 复杂状态 |
| `ObservableValue` | 单个值 | 隔离逻辑 |

---

### 4. 依赖注入与实例共享
使用明确的参数系统进行依赖注入，并支持跨 Widget 的实例共享。

```dart
final userProvider = ViewModelProvider.arg<UserViewModel, int>(
  builder: (id) => UserViewModel(id),
  key: (id) => 'user_$id', // 每个 ID 共享一个实例
);

// 使用
final vm = vef.watch(userProvider(42));
```

---

### 5. 生命周期管理
- **自动生命周期**：ViewModel 在首次使用时创建，在最后一个 vefer 解绑 (unbind) 时自动销毁。
- **全局单例**：使用 `aliveForever: true`（如 Auth、Config）。

---

## 测试
使用 `setProxy` 即可轻松进行 Mock 测试：

```dart
testWidgets('测试 UI', (tester) async {
  final mockVM = MockUserViewModel();
  userProvider.setProxy(ViewModelProvider(builder: () => mockVM));
  
  await tester.pumpWidget(MyApp());
  expect(find.text('Alice'), findsOneWidget);
});
```

---

## 全局配置
在 `main()` 中初始化以自定义行为：

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
