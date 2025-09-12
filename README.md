# ViewModel

[![Powered by Mason](https://img.shields.io/endpoint?url=https%3A%2F%2Ftinyurl.com%2Fmason-badge)](https://github.com/felangel/mason)

A powerful and flexible ViewModel library for Flutter that simplifies state management and promotes clean architecture.

## Features

- **Automatic Lifecycle Management**: ViewModels are automatically created and disposed of in sync with your `StatefulWidget`'s lifecycle.
- **Dependency Injection**: Easily provide dependencies to your ViewModels.
- **State Restoration**: (Coming Soon) Automatically save and restore ViewModel state.
- **Lazy Initialization**: ViewModels are created only when they are first accessed.
- **Global ViewModels**: Create and access singleton ViewModels from anywhere in your app.
- **ViewModel-to-ViewModel Dependencies**: Build complex dependency graphs between your ViewModels.

## Getting Started

Add the `view_model` package to your `pubspec.yaml`:

```yaml
dependencies:
  view_model: ^latest_version
```

## Core Concepts

### ViewModel

A `ViewModel` is a class that holds and manages UI-related data. It survives configuration changes (like screen rotations) and remains in memory as long as its associated UI component (like a `StatefulWidget`) is alive.

To create a ViewModel, simply mix in the `ViewModel` class:

```dart
class MyViewModel with ViewModel {
  // ... your view model logic
}
```

### ViewModelStateMixin

To connect a `ViewModel` to a `StatefulWidget`, use the `ViewModelStateMixin` on your `State` class. This mixin handles the lifecycle of your ViewModels, automatically creating and disposing of them.

```dart
class MyWidget extends StatefulWidget {
  // ...
}

class MyWidgetState extends State<MyWidget> with ViewModelStateMixin<MyWidget> {
  // ...
}
```

## Usage

### Creating and Watching a ViewModel

Inside your `State` class (that uses `ViewModelStateMixin`), you can create and watch a `ViewModel` using the `watchViewModel` method.

- **`factory`**: A `ViewModelFactory` that creates the `ViewModel` instance. `DefaultViewModelFactory` is a simple way to provide a builder function.
- **`key`**: An optional `String` key. ViewModels with the same key are shared instances. This is useful for sharing a `ViewModel` between multiple widgets.

```dart
class MyWidgetState extends State<MyWidget> with ViewModelStateMixin<MyWidget> {
  late MyViewModel vm;

  @override
  void initState() {
    super.initState();
    vm = watchViewModel<MyViewModel>(
      key: 'my_unique_key', // Optional: for sharing
      factory: DefaultViewModelFactory(builder: () => MyViewModel()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Use your vm instance here
    return Text(vm.someData);
  }
}
```

### Sharing ViewModels

When two or more widgets use `watchViewModel` with the same `key`, they will receive the exact same `ViewModel` instance. The `ViewModel`'s lifecycle is tied to all widgets watching it. It will only be disposed of when the *last* widget watching it is removed from the widget tree.

This mechanism is particularly useful for master-detail views or any scenario where different parts of the UI need to react to the same state.

**Example:**

Imagine two widgets, `WidgetA` and `WidgetB`, both needing access to `SharedViewModel`.

```dart
// state_a.dart
class WidgetAState extends State<WidgetA> with ViewModelStateMixin<WidgetA> {
  @override
  void initState() {
    super.initState();
    // Watch the shared ViewModel
    final vm = watchViewModel<SharedViewModel>(key: 'shared');
  }
  // ...
}

// state_b.dart
class WidgetBState extends State<WidgetB> with ViewModelStateMixin<WidgetB> {
  @override
  void initState() {
    super.initState();
    // Watch the same shared ViewModel
    final vm = watchViewModel<SharedViewModel>(key: 'shared');
  }
  // ...
}
```

When `WidgetA` is disposed, the `SharedViewModel` is **not** disposed because `WidgetB` is still watching it. The `ViewModel`'s internal dependency resolver is simply transferred to `WidgetB`. The `ViewModel` will only be disposed of when `WidgetB` is also disposed.

### Accessing Global ViewModels

You can also create global (singleton) ViewModels that are not tied to any specific widget's lifecycle.

```dart
// Create a global instance
final myGlobalViewModel = instanceManager.put(MyGlobalViewModel());

// Access it from anywhere
final myGlobalViewModel = instanceManager.get<MyGlobalViewModel>();
```

### ViewModel Dependencies

Your ViewModels can depend on other ViewModels.

```dart
class UserViewModel with ViewModel {
  final UserRepository userRepo;
  UserViewModel(this.userRepo);
}

class AuthViewModel with ViewModel {
  // AuthViewModel depends on UserViewModel
  final userViewModel = getViewModel<UserViewModel>();
}
```

This promotes a clean separation of concerns and allows you to build a scalable and maintainable architecture.

