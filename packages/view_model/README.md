<p align="center">
  <img src="https://lwjlol-images.oss-cn-beijing.aliyuncs.com/logo.png" alt="ViewModel Logo" height="96" />
</p>

# view_model: Flutter-Native State Management

Designed for Flutter's OOP and Widget style. Low intrusion, VM-to-VM access, flexible ViewModel definitions, and fine-grained updates. Built specifically for Flutter.

| Package | Version |
| :--- | :--- |
| **view_model** | [![Pub Version](https://img.shields.io/pub/v/view_model)](https://img.shields.io/pub/v/view_model) |
| **view_model_annotation** | [![Pub Version](https://img.shields.io/pub/v/view_model_annotation)](https://img.shields.io/pub/v/view_model_annotation) |
| **view_model_generator** | [![Pub Version](https://img.shields.io/pub/v/view_model_generator)](https://img.shields.io/pub/v/view_model_generator) |

[![Codecov](https://img.shields.io/codecov/c/github/lwj1994/flutter_view_model/main)](https://app.codecov.io/gh/lwj1994/flutter_view_model/tree/main)

[ChangeLog](https://github.com/lwj1994/flutter_view_model/blob/main/packages/view_model/CHANGELOG.md) | [中文文档](README_ZH.md) | [Architecture Guide](ARCHITECTURE_GUIDE.md)

---

## Agent Skills
See [Agent Skills](https://github.com/lwj1994/flutter_view_model/blob/main/skills/view_model/SKILL.md) for AI Agent usage.

## Why view_model?
Developed by a mobile development team (Android, iOS, Flutter) accustomed to MVVM. This library provides a native Flutter implementation of the ViewModel concept, addressing the limitations of existing state management solutions.

---

## Installation

```yaml
dependencies:
  view_model: ^latest_version

dev_dependencies:
  build_runner: ^latest_version
  view_model_generator: ^latest_version
```

---

## Quick Start

### 1. Define ViewModel
Use the `ViewModel` mixin for your business logic. 

```dart
class CounterViewModel with ViewModel {
  int count = 0;

  void increment() {
    update(() => count++); // Notifies listeners
  }
}
```

### 2. Register Provider
```dart
final counterProvider = ViewModelProvider<CounterViewModel>(
  builder: () => CounterViewModel(),
);
```
*Tip: Use `view_model_generator` to automate provider generation.*

### 3. Use in Widget
Apply `ViewModelStateMixin` to your State class to access the `vef` API.

```dart
class _CounterPageState extends State<CounterPage> with ViewModelStateMixin {
  @override
  Widget build(BuildContext context) {
    // watch() automatically listens for changes
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

### Comparison

| Solution | Changes Required | Root Wrapping | BuildContext Dependency |
|----------|------------------|---------------|------------------------|
| **view_model** | Add mixin | No | No |
| Provider | InheritedWidget | Yes | Yes |
| Riverpod | ConsumerWidget | Yes | No |
| GetX | Global state | No | No |

---

## Core Features

### 1. Universal Access (Vef)
`Vef` (ViewModel Execution Framework) provides a consistent API to access ViewModels across Widgets, ViewModels, and pure Dart classes.

| Method | Behavior | Use Case |
| :--- | :--- | :--- |
| `vef.watch` | Reactive | Inside `build()`, triggers rebuilds |
| `vef.read` | Direct access | Callbacks, event handlers |
| `vef.listen` | Side effects | Navigation, notifications |
| `vef.listenState` | State Listener | Monitor state transitions |

#### Usage Examples
- **Widgets**: Use `ViewModelStateMixin`.
- **ViewModels**: Built-in access to other ViewModels.
- **Pure Classes**: Use `with Vef`.

```dart
class TaskRunner with Vef {
  void run() {
    final authVM = vef.read(authProvider);
    authVM.checkAuth();
  }
}
```

### 2. Pause Mechanism
To save resources, `view_model` automatically defers UI updates when a widget is not visible (e.g., covered by another route, app in background, or hidden in a TabBar).

- **Automatic**: `ViewModelStateMixin` handles this by default using `AppPauseProvider`, `PageRoutePauseProvider`, and `TickerModePauseProvider`.
- **Deferred Updates**: When paused, notifications from ViewModels are queued. A single rebuild is triggered only when the widget becomes visible again.

---

### 3. Fine-Grained Reactivity
Optimize performance by rebuilding only what is necessary.

- **StateViewModelValueWatcher**: Rebuild when specific fields of a `StateViewModel` change.
- **ObservableValue & ObserverBuilder**: Standalone reactive values for isolated state.

| Approach | Scope | Best For |
|----------|--------------|----------|
| `vef.watch` | Entire widget | Simple cases |
| `StateViewModelValueWatcher` | Selected fields | Complex states |
| `ObservableValue` | Single value | Isolated logic |

---

### 4. Dependency Injection & Instance Sharing
Use an explicit argument system for dependency injection and cross-widget instance sharing.

```dart
final userProvider = ViewModelProvider.arg<UserViewModel, int>(
  builder: (id) => UserViewModel(id),
  key: (id) => 'user_$id', // Shared instance per ID
);

// Usage
final vm = vef.watch(userProvider(42));
```

---

### 5. Lifecycle Management
- **Auto-Lifecycle**: ViewModels are created on first use and disposed when the last vefer unbinds.
- **Singletons**: Use `aliveForever: true` for global services (e.g., Auth, Config).

---

## Testing
Mocking is straightforward using `setProxy`:

```dart
testWidgets('Test UI', (tester) async {
  final mockVM = MockUserViewModel();
  userProvider.setProxy(ViewModelProvider(builder: () => mockVM));
  
  await tester.pumpWidget(MyApp());
  expect(find.text('Alice'), findsOneWidget);
});
```

---

## Global Configuration
Initialize in `main()` to customize system behavior:

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

| Parameter | Default | Description |
| :--- | :--- | :--- |
| `isLoggingEnabled` | `false` | Toggle debug logs |
| `equals` | `identical` | Equality logic for state |
| `onListenerError` | `null` | Global listener error handler |
| `onDisposeError` | `null` | Global disposal error handler |
