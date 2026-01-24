# view_model

Lightweight Flutter state management that makes it simple.

[![pub package](https://img.shields.io/pub/v/view_model.svg)](https://pub.dev/packages/view_model)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

English | [简体中文](README_ZH.md)

## Why view_model?

- **Minimal boilerplate** - Just add a mixin, no root wrappers or complex setup
- **Automatic lifecycle** - Auto cleanup when widgets dispose, prevents memory leaks
- **Smart performance** - Auto-pause updates for background or hidden pages
- **Fine-grained reactivity** - Field-level updates, rebuild only what changed
- **ViewModel dependencies** - ViewModels can directly access and listen to each other

## Quick Start

### Installation

```yaml
dependencies:
  view_model: ^0.14.2
```

### Three Simple Steps

#### 1. Define State Class

```dart
class CounterState {
  final int count;

  const CounterState({this.count = 0});

  CounterState copyWith({int? count}) {
    return CounterState(count: count ?? this.count);
  }
}
```

#### 2. Create ViewModel

```dart
import 'package:view_model/view_model.dart';

// Define Provider (global singleton)
final counterProvider = ViewModelProvider<CounterViewModel>(
  key: 'counter',  // Use key to share instance
  builder: () => CounterViewModel(),
);

// Create ViewModel
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

#### 3. Use in Widget

```dart
class CounterPage extends StatefulWidget {
  const CounterPage({super.key});

  @override
  State<CounterPage> createState() => _CounterPageState();
}

// Add ViewModelStateMixin
class _CounterPageState extends State<CounterPage>
    with ViewModelStateMixin<CounterPage> {

  @override
  Widget build(BuildContext context) {
    // Use vef.watch to listen to ViewModel
    final counter = vef.watch(counterProvider);

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
                  onPressed: counter.decrement,
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

### Initialization (Optional)

```dart
void main() {
  ViewModel.initialize(
    config: ViewModelConfig(
      isLoggingEnabled: true,  // Enable logging
    ),
  );
  runApp(const MyApp());
}
```

## Core Concepts

### Vef - ViewModel Execution Framework

Vef provides four core methods to access ViewModels:

| Method | Usage | Effect |
|--------|-------|--------|
| `vef.watch(provider)` | In build method | Listen to changes and rebuild widget |
| `vef.read(provider)` | In event callbacks | Read data without listening |
| `vef.watchCached({key})` | Access existing instance | Listen to cached ViewModel |
| `vef.readCached({key})` | Read existing instance | Don't listen to cached ViewModel |

```dart
// Example: watch vs read
@override
Widget build(BuildContext context) {
  final vm = vef.watch(provider);  // ✅ Use watch in build
  return ElevatedButton(
    onPressed: () {
      final vm = vef.read(provider);  // ✅ Use read in callbacks
      vm.doSomething();
    },
    child: Text(vm.state.title),
  );
}
```

### Instance Sharing and Lifecycle

#### 1. Auto Cleanup (Default)

Without `key`, each widget has its own instance, auto-disposed when widget unmounts:

```dart
final provider = ViewModelProvider<MyViewModel>(
  builder: () => MyViewModel(),
  // No key, auto cleanup
);
```

#### 2. Shared Instance

With `key`, widgets with same key share one instance, disposed when all widgets unmount:

```dart
final userProvider = ViewModelProvider<UserViewModel>(
  key: 'current-user',  // All widgets with this key share instance
  builder: () => UserViewModel(),
);
```

#### 3. Keep Alive Forever

With `aliveForever: true`, instance never disposes:

```dart
final configProvider = ViewModelProvider<ConfigViewModel>(
  key: 'app-config',
  aliveForever: true,  // Never dispose
  builder: () => ConfigViewModel(),
);
```

### Smart Pause Mechanism

Built-in auto-pause to save performance:

1. **App Background Pause** - Pause when app goes to background
2. **Route Overlay Pause** - Pause when route is covered by another route
3. **TabBar Pause** - Pause invisible tabs in TabBarView

Updates are queued while paused, triggered once when resumed to avoid wasted rebuilds.

#### Enable Route Pause

```dart
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorObservers: [ViewModel.routeObserver],  // Add route observer
      home: HomePage(),
    );
  }
}
```

### Parameterized Providers

Create and reuse instances based on parameters:

```dart
// Define provider with parameter
final userProvider = ViewModelProvider.arg<UserViewModel, int>(
  builder: (userId) => UserViewModel(userId),
  key: (userId) => 'user_$userId',  // Different params use different keys
);

// Usage
Widget build(BuildContext context) {
  final user1 = vef.watch(userProvider(42));   // Create user_42
  final user2 = vef.watch(userProvider(100));  // Create user_100
  final user3 = vef.watch(userProvider(42));   // Reuse user_42
}
```

Supports 1-4 parameters: `arg`, `arg2`, `arg3`, `arg4`

### ViewModel Dependencies

ViewModels can directly access other ViewModels:

```dart
class UserProfileViewModel extends StateViewModel<UserState> {

  void loadProfile() {
    // Read auth ViewModel
    final auth = vef.read(authProvider);

    if (auth.isLoggedIn) {
      // Load user data...
    }
  }

  // Listen to other ViewModel changes
  @override
  void onCreate(InstanceArg arg) {
    super.onCreate(arg);

    listenState(authProvider, (previous, next) {
      if (next.isLoggedOut) {
        // Clear user data
        setState(const UserState());
      }
    });
  }
}
```

### Fine-Grained Reactivity

#### 1. ValueWatcher - Field-Level Rebuild

Only listen to specific fields in state, reduce unnecessary rebuilds:

```dart
StateViewModelValueWatcher<UserViewModel, UserState>(
  stateViewModel: userViewModel,
  selectors: [
    (state) => state.name,  // Only listen to name
    (state) => state.age,   // Only listen to age
  ],
  builder: (state) => Text('${state.name}, ${state.age}'),
)
```

#### 2. ObservableValue - Standalone Reactive Value

Create independent reactive values without ViewModels:

```dart
// Create shared reactive value
final counter = ObservableValue<int>(0, shareKey: 'counter');

// Modify anywhere
counter.value = 42;

// Listen in widget
ObserverBuilder<int>(
  observable: counter,
  builder: (value) => Text('$value'),
)
```

### Lifecycle Hooks

```dart
class MyViewModel extends StateViewModel<MyState> {
  @override
  void onCreate(InstanceArg arg) {
    super.onCreate(arg);
    // Initialize resources
    print('ViewModel created');
  }

  @override
  void onBindVef(InstanceArg arg, String vefId) {
    super.onBindVef(arg, vefId);
    // New widget started listening
    print('Widget bound');
  }

  @override
  void onUnbindVef(InstanceArg arg, String vefId) {
    super.onUnbindVef(arg, vefId);
    // Widget stopped listening
    print('Widget unbound');
  }

  @override
  void onDispose(InstanceArg arg) {
    // Cleanup resources
    print('ViewModel disposed');
    super.onDispose(arg);
  }
}
```

## Code Generation

Use `@GenProvider` annotation to auto-generate providers:

### 1. Add Dependencies

```yaml
dependencies:
  view_model: ^0.14.2
  view_model_annotation: ^0.14.2

dev_dependencies:
  view_model_generator: ^0.14.2
  build_runner: ^2.4.0
```

### 2. Use Annotation

```dart
import 'package:view_model_annotation/view_model_annotation.dart';

part 'user_view_model.vm.dart';  // Generated file

@GenProvider(
  key: Expression('user_\$userId'),  // Supports string interpolation
  aliveForever: false,
)
class UserViewModel extends StateViewModel<UserState> {
  factory UserViewModel.provider(int userId) => UserViewModel(userId);

  UserViewModel(this.userId) : super(state: UserState());

  final int userId;
}
```

### 3. Run Generation

```bash
dart run build_runner build
```

Generated code:

```dart
// user_view_model.vm.dart
final userProvider = ViewModelProvider.arg<UserViewModel, int>(
  builder: (userId) => UserViewModel(userId),
  key: (userId) => 'user_$userId',
);
```

## Advanced Features

### Use in Plain Dart Classes

Not limited to widgets, any Dart class can use it:

```dart
class StartupTask with Vef {
  Future<void> run() async {
    final config = vef.read(configProvider);
    await config.initialize();

    final auth = vef.read(authProvider);
    await auth.checkLogin();
  }
}

// Use in main
void main() {
  ViewModel.initialize();
  StartupTask().run();
  runApp(MyApp());
}
```

### Repository as ViewModel

```dart
class UserRepository with ViewModel {

  Future<User> fetchUser(int id) async {
    // Can access other ViewModels
    final token = vef.read(authProvider).token;
    return await api.getUser(id, token);
  }
}

final userRepoProvider = ViewModelProvider<UserRepository>(
  builder: () => UserRepository(),
);
```

### Global Lifecycle Observation

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

## Comparison

| Feature | view_model | Provider | Riverpod | GetX |
|---------|-----------|----------|----------|------|
| Boilerplate | Minimal (mixin) | Medium | Low | Low |
| Root wrapper | ❌ | ✅ | ✅ | ❌ |
| Auto lifecycle | ✅ | ❌ | ✅ | ✅ |
| Smart pause | ✅ | ❌ | ❌ | ❌ |
| ViewModel deps | ✅ | ❌ | ✅ | ❌ |
| Field-level reactivity | ✅ | ❌ | ❌ | ✅ |
| BuildContext | Not needed | Needed | Not needed | Not needed |

## Examples

Check [example](../../example) directory:

- [counter](../../example/counter) - Simple counter showing basic usage
- [todo_list](../../example/todo_list) - TODO app showing complex state management

## Documentation

- [Architecture Guide](ARCHITECTURE_GUIDE.md)
- [Pause and Resume Mechanism](../../docs/PAUSE_RESUME_LIFECYCLE.md)
- [ValueObserver Documentation](../../docs/value_observer_doc.md)
- [Code Generation Guide](../../docs/build_runner.md)

## License

MIT License - See [LICENSE](../../LICENSE) file

## Contributing

Issues and Pull Requests are welcome!

Report issues at: https://github.com/lwj1994/flutter_view_model/issues
