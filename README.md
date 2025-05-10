# view_model

[![Static Badge](https://img.shields.io/badge/pub-0.3.0-brightgreen)](https://pub.dev/packages/view_model) [![Codecov (with branch)](https://img.shields.io/codecov/c/github/lwj1994/flutter_view_model/main)](https://app.codecov.io/gh/lwj1994/flutter_view_model/tree/main)

[Chinese](README_ZH.md)

I sincerely thank [Miolin](https://github.com/Miolin) for entrusting me with the permissions of
the [view_model](https://pub.dev/packages/view_model) package and transferring its ownership. This
support is invaluable, and I'm excited to drive its continuous development.

## Features

- **Simple and Lightweight**: It has a streamlined architecture with minimal resource overhead,
  ensuring high - efficiency performance.
- **Transparent Implementation**: Built on `StreamController` and `setState`, its internal logic is
  simple and easy to understand, with no hidden complexities.
- **Automatic Resource Disposal**: Resources are automatically released along with the `State` of a
  `StatefulWidget`, simplifying memory management.
- **Cross - Widget Sharing**: It can be shared across multiple `StatefulWidget`s, promoting code
  reusability and modularity.

> **Note**: `ViewModel` is designed to bind only to the `State` of a `StatefulWidget`. Since
`StatelessWidget`s don't maintain state, they are not compatible with this binding mechanism.

## Core Concepts

- **ViewModel**: Serves as the core for state management. It holds the application state and
  notifies registered listeners when the state changes.
- **ViewModelFactory**: Defines how `ViewModel`s are instantiated and configured.
- **watchViewModel**: Creates a new `ViewModel` instance or retrieves an existing one, and
  automatically triggers `setState`.
- **readViewModel**: Retrieves an existing `ViewModel` or creates one using the factory, without
  triggering `setState`.

## Stateless and Stateful ViewModels

By default, `ViewModel` operates in stateless mode.

### Stateless ViewModel

- **Simplified Usage**: It's a lightweight option without an internal `state`.
- **Change Notification**: Data changes are notified to listeners via the `notifyListeners()`
  method.

### Stateful ViewModel

- **State - Oriented**: It must hold an internal `state` object.
- **Immutability Principle**: The `state` is immutable, ensuring data integrity and predictability.
- **State Updates**: State changes are made through the `setState()` method, which triggers a widget
  rebuild.

## Step - by - Step Guide

Using the `view_model` package is straightforward. Follow these four steps:

Add Dependency:

```yaml
dependencies:
  view_model: ^0.4.0
```

### 1. Define a State Class (for Stateful ViewModel)

For stateful view models, create an immutable state class first:

```dart
class MyState {
  final String name;

  const MyState({required this.name});

  MyState copyWith({String? name}) =>
      MyState(
        name: name ?? this.name,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          (other is MyState && runtimeType == other.runtimeType && name == other.name);

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => 'MyState{name: $name}';
}
```

> **Tip**: If you don't need to manage complex state, skip this step and use a Stateless ViewModel (
> see Step 2).

### 2. Create a ViewModel

Extend either `ViewModel<T>` for stateless scenarios or `StateViewModel` for stateful management.

**Example: Stateless ViewModel**

```dart
import 'package:view_model/view_model.dart';

class MyViewModel extends ViewModel {
  String name = "Initial Name";

  void updateName(String newName) {
    name = newName;
    notifyListeners();
  }
}
```

**Example: Stateful ViewModel**

```dart
import 'package:view_model/view_model.dart';

class MyViewModel extends StateViewModel<MyState> {
  MyViewModel({required super.state});

  void updateName(String newName) {
    setState(state.copyWith(name: newName));
  }

  @override
  void dispose() async {
    super.dispose();
    debugPrint('Disposed MyViewModel: $state');
  }
}
```

### 3. Implement a ViewModelFactory

Use a `ViewModelFactory` to specify how your `ViewModel` is instantiated:

```dart
class MyViewModelFactory with ViewModelFactory<MyViewModel> {
  final String initialName;

  MyViewModelFactory({this.initialName = ""});

  @override
  MyViewModel build() => MyViewModel(state: MyState(name: initialName));

  // Optional: Enable singleton sharing. Only applicable when key() returns null.
  @override
  bool singleton() => true;

  // Optional: Share ViewModel based on a custom key.
  @override
  String? key() => initialName;
}
```

### 4. Integrate ViewModel into Your Widget

In a `StatefulWidget`, use `watchViewModel` to access the view model:

```dart
import 'package:view_model/view_model.dart';

class _MyPageState extends State<MyPage> with ViewModelStateMixin<MyPage> {
  MyViewModel get viewModel =>
      watchViewModel<MyViewModel>(factory: MyViewModelFactory(initialName: "Hello"));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(viewModel.state.name),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => viewModel.updateName("New Name"),
        child: Icon(Icons.refresh),
      ),
    );
  }
}
```

> **Note**: Additional features like change listening, view model refresh, and cross - page sharing
> are also supported. See the sections below for details.

## Advanced APIs

### Listening for State Changes

```dart
@override
void initState() {
  super.initState();
  final dispose = viewModel.listenState(onChanged: (prev, next) {
    print('State changed: $prev -> $next');
  });

  final dispose2 = viewModel.listen(onChanged: () {
    print('viewModel notifyListeners');
  });
}
```

### Retrieving Existing ViewModels

Use `readViewModel` to get an existing view model.

```dart
// Find newly created <MyViewModel> instance
MyViewModel get viewModel => readViewModel<MyViewModel>();

// Find <MyViewModel> instance by key
MyViewModel get viewModel => readViewModel<MyViewModel>(key: "my-key");

// if not find ("my-key"), will fallback to use MyViewModelFactory create instance
MyViewModel get viewModel =>
    readViewModel<MyViewModel>(key: "my-key", factory: MyViewModelFactory());
```

read existing view model globally:

```dart

final T vm = ViewModel.read<T>(key: "shareKey");
```

### Refreshing ViewModel

Create a new instance of the view model:

```dart
MyViewModel get viewModel =>
    watchViewModel<MyViewModel>(key: "my-key", factory: MyViewModelFactory());

void refresh() {
  refreshViewModel(viewModel);

  // This will obtain a new instance
  viewModel = readViewModel<MyViewModel>(
    key: "my-key",
  );
}
``` 

## About Partial Refresh

The state manager doesn't need to handle partial UI refreshes — the Flutter engine automatically
performs UI diffing.
A widget's build method is simply a configuration step, and triggering it doesn't incur significant
performance overhead.

To achieve fine-grained updates, we can use ValueListenableBuilder.

```dart
@override
Widget build(BuildContext context) {
  return ValueNotifierBuilder(
    valueListenable: _notifier,
    builder: (context, value, child) {
      return Text(value);
    },
  );
}
```

