# view_model

A Flutter ViewModel system built around a single idea:
everything can be a ViewModel.

| Package | Version |
| :--- | :--- |
| **view_model** | [![Pub Version](https://img.shields.io/pub/v/view_model)](https://pub.dev/packages/view_model) |
| **view_model_annotation** | [![Pub Version](https://img.shields.io/pub/v/view_model_annotation)](https://pub.dev/packages/view_model_annotation) |
| **view_model_generator** | [![Pub Version](https://img.shields.io/pub/v/view_model_generator)](https://pub.dev/packages/view_model_generator) |

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

English | [简体中文](README_ZH.md)

## What It Is

`view_model` is a ViewModel runtime with lifecycle management,
dependency resolution, and fine-grained updates.
It binds ViewModel lifetime to the widget tree while keeping business logic
independent from widgets.

## Why It Feels Different

- A ViewModel is any class with `ViewModel` or `StateViewModel`
- A widget consumes ViewModels through `ViewModelBinding`
- Instances are cached, shared, and disposed automatically
- Updates can be paused when a widget is not visible
- State selection enables small, targeted rebuilds

## Installation

```yaml
dependencies:
  view_model: ^0.15.0-dev.0
```

## Getting Started

### 1) State

```dart
class CounterState {
  final int count;

  const CounterState({this.count = 0});

  CounterState copyWith({int? count}) {
    return CounterState(count: count ?? this.count);
  }
}
```

### 2) ViewModel + Spec

```dart
import 'package:view_model/view_model.dart';

final counterSpec = ViewModelSpec<CounterViewModel>(
  key: 'counter',
  builder: () => CounterViewModel(),
);

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

### 3) Widget Binding

```dart
class CounterPage extends StatefulWidget {
  const CounterPage({super.key});

  @override
  State<CounterPage> createState() => _CounterPageState();
}

class _CounterPageState extends State<CounterPage>
    with ViewModelStateMixin<CounterPage> {
  @override
  Widget build(BuildContext context) {
    final counter = viewModelBinding.watch(counterSpec);

    return Text('${counter.state.count}');
  }
}
```

## Binding API

`ViewModelBinding` is the entry point for all access.

| Method | Use | Behavior |
| :--- | :--- | :--- |
| `watch(factory)` | build | Rebuild on change |
| `read(factory)` | callbacks | Read without rebuild |
| `watchCached({key, tag})` | build | Watch cached instance |
| `readCached({key, tag})` | callbacks | Read cached instance |
| `maybeWatchCached({key, tag})` | build | Nullable watch |
| `maybeReadCached({key, tag})` | callbacks | Nullable read |
| `listen(factory, onChanged)` | effects | Auto-dispose listener |
| `listenState(factory, onChanged)` | state | Previous and next |
| `listenStateSelect(factory, ...)` | state | Selected updates |

## Widget Integration

Choose the integration style that fits your widget:

- `ViewModelStateMixin` for StatefulWidget
- `ViewModelStatelessMixin` for StatelessWidget
- `ViewModelBuilder` for a builder-style widget

```dart
class CounterSection extends StatelessWidget {
  const CounterSection({super.key});

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder<CounterViewModel>(
      counterSpec,
      builder: (vm) => Text('${vm.state.count}'),
    );
  }
}
```

## Lifecycle and Sharing

```dart
final localSpec = ViewModelSpec<MyViewModel>(
  builder: () => MyViewModel(),
);

final sharedSpec = ViewModelSpec<UserViewModel>(
  key: 'current-user',
  builder: () => UserViewModel(),
);

final globalSpec = ViewModelSpec<ConfigViewModel>(
  key: 'app-config',
  aliveForever: true,
  builder: () => ConfigViewModel(),
);
```

## Parameterized Specs

```dart
final userSpec = ViewModelSpec.arg<UserViewModel, int>(
  builder: (userId) => UserViewModel(userId),
  key: (userId) => 'user_$userId',
);

final pageSpec = ViewModelSpec.arg2<PageViewModel, String, int>(
  builder: (tab, page) => PageViewModel(tab, page),
  tag: (tab, page) => '$tab-$page',
);
```

Supports `arg`, `arg2`, `arg3`, and `arg4`.

## ViewModel to ViewModel

```dart
final authSpec = ViewModelSpec<AuthViewModel>(
  builder: () => AuthViewModel(),
);

class ProfileViewModel extends StateViewModel<ProfileState> {
  ProfileViewModel() : super(state: const ProfileState());

  void load() {
    final auth = read(authSpec);
    if (auth.isLoggedIn) {
      fetchProfile();
    }
  }

  @override
  void onCreate(InstanceArg arg) {
    super.onCreate(arg);
    listenState(authSpec, (previous, next) {
      if (next.isLoggedOut) {
        setState(const ProfileState());
      }
    });
  }
}
```

## Pause and Resume

Updates are paused while widgets are not visible and resume in a batch.

```dart
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorObservers: [ViewModel.routeObserver],
      home: const HomePage(),
    );
  }
}
```

## Fine-Grained Reactivity

```dart
StateViewModelValueWatcher<UserViewModel, UserState>(
  stateViewModel: userViewModel,
  selectors: [
    (state) => state.name,
    (state) => state.age,
  ],
  builder: (state) => Text('${state.name}, ${state.age}'),
)
```

```dart
final counter = ObservableValue<int>(0, shareKey: 'counter');

ObserverBuilder<int>(
  observable: counter,
  builder: (value) => Text('$value'),
)
```

## Use Without Widgets

```dart
class StartupTask with ViewModelBinding {
  Future<void> run() async {
    final config = read(configSpec);
    await config.initialize();
  }
}

final configSpec = ViewModelSpec<ConfigViewModel>(
  builder: () => ConfigViewModel(),
);
```

## DevTools

The package includes a DevTools extension for inspecting ViewModels and
their relationships at runtime.

## Code Generation

`@GenSpec` generates specs automatically.
See [view_model_generator](../view_model_generator/README.md).

```dart
import 'package:view_model_annotation/view_model_annotation.dart';

part 'user_view_model.vm.dart';

@GenSpec(key: r'${userId}')
class UserViewModel extends StateViewModel<UserState> {
  UserViewModel(this.userId) : super(state: UserState());

  final int userId;
}
```

## Examples

- [counter](../../example/counter)
- [todo_list](../../example/todo_list)

## Documentation

- [Architecture Guide](ARCHITECTURE_GUIDE.md)
- [Pause and Resume Mechanism](../../docs/PAUSE_RESUME_LIFECYCLE.md)
- [ValueObserver Documentation](../../docs/value_observer_doc.md)
- [Code Generation Guide](../../docs/build_runner.md)

## License

MIT License - See [LICENSE](../../LICENSE)

## Contributing

Issues and Pull Requests are welcome.

Report issues at: https://github.com/lwj1994/flutter_view_model/issues
