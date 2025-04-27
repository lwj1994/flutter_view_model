# view_model
[![Static Badge](https://img.shields.io/badge/pub-0.3.0-brightgreen)](https://pub.dev/packages/view_model) [![Codecov (with branch)](https://img.shields.io/codecov/c/github/lwj1994/flutter_view_model/main)](https://app.codecov.io/gh/lwj1994/flutter_view_model/tree/main)

[中文文档](README_ZH.md)

I would like to express my sincere gratitude to [Miolin](https://github.com/Miolin) for entrusting
me with the permissions of the [view_model](https://pub.dev/packages/view_model) package and
transferring its ownership. This support is invaluable, and I'm truly thrilled to drive its
continuous development forward. Thank you!

## Features

- **Simplicity and Lightweight Design**: Boasts a streamlined architecture with minimal resource
  overhead, ensuring efficient performance.
- **Transparent Implementation**: Built on `StreamController` and `setState`, its internal logic is
  straightforward and easily comprehensible, eliminating any hidden complexities.
- **Automatic Resource Disposal**: Resources are automatically released in tandem with the `State`
  of a `StatefulWidget`, simplifying memory management.
- **Cross - Widget Sharing**: Can be shared across multiple `StatefulWidget`s, promoting code
  reusability and modularity.

> **Important Note**: `ViewModel` is designed to be bound exclusively to the `State` of a
`StatefulWidget`. Since `StatelessWidget`s do not maintain state, they are not compatible with this
> binding mechanism.

## Core Concepts

- **ViewModel**: Serves as the central repository for state management. It holds the application
  state and notifies registered listeners whenever the state undergoes a change.
- **ViewModelFactory**: Defines the instantiation logic for `ViewModel`s, specifying how they are
  created and configured.
- **getViewModel**: A utility function used to either create a new `ViewModel` instance or retrieve
  an existing one, facilitating easy access to view models within the application.

## Stateful and Stateless ViewModels

By default, `ViewModel` operates in a stateful mode.

### Stateful ViewModel

- **State - Centric**: Mandatorily holds an internal `state` object.
- **Immutability Principle**: The `state` is designed to be immutable, ensuring data integrity and
  predictability.
- **State Updates**: State modifications are achieved through the `setState()` method, which
  triggers a rebuild of the associated widgets.

### Stateless ViewModel

- **Simplified Approach**: Offers a more lightweight alternative without maintaining an internal
  `state`.
- **Change Notification**: Data changes are communicated to listeners by invoking the
  `notifyListeners()` method.

## Step - by - Step Guide to Using ViewModel

Using the `view_model` package is a straightforward process. Follow these four steps:

Add Dependency:
```yaml
dependencies:
  view_model: ^0.3.0
```

### 1. Define a State Class (for Stateful ViewModel)

For stateful view models, start by creating an immutable state class:

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

> **Pro Tip**: If your use case doesn't require managing complex state, you can skip this step and
> opt for a Stateless ViewModel instead (refer to Step 2).

### 2. Create a ViewModel

Extend either `ViewModel<T>` for stateful management or `StatelessViewModel` for stateless
scenarios:

**Example: Stateful ViewModel**

```dart
import 'package:view_model/view_model.dart';

class MyViewModel extends ViewModel<MyState> {
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

**Example: Stateless ViewModel**

```dart
import 'package:view_model/view_model.dart';

class MyViewModel extends StatelessViewModel {
  String name = "Initial Name";

  void updateName(String newName) {
    name = newName;
    notifyListeners();
  }
}
```

### 3. Implement a ViewModelFactory

Use a `ViewModelFactory` to specify how your `ViewModel` should be instantiated:

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

In a `StatefulWidget`, utilize `getViewModel` to access the view model:

```dart
import 'package:view_model/view_model.dart';

class _MyPageState extends State<MyPage> with ViewModelStateMixin<MyPage> {
  MyViewModel get viewModel =>
      getViewModel<MyViewModel>(factory: MyViewModelFactory(initialName: "Hello"));

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

> **Note**: Additional functionality such as change listening, view model refresh, and cross - page
> sharing are also supported. Refer to the sections below for more details.

## Advanced APIs

### Listening for State Changes

```dart
@override
void initState() {
  super.initState();
  viewModel.listen(onChanged: (prev, next) {
    print('State changed: $prev -> $next');
  });
}
```

### Retrieving Existing ViewModels

**Option 1**: Use `getViewModel` to fetch an existing view model (creates a new one if not found):

```dart
MyViewModel get viewModel =>
    getViewModel<MyViewModel>(factory: MyViewModelFactory(
      key: "my-key",
    ));
```

**Option 2**: Use `requireExistingViewModel` to retrieve only existing view models (throws an
exception if not found):

```dart
// Find newly created <MyViewModel> instance
MyViewModel get viewModel => requireExistingViewModel<MyViewModel>();

// Find <MyViewModel> instance by key
MyViewModel get viewModel => requireExistingViewModel<MyViewModel>(key: "my-key");
```

### Refreshing ViewModel

Create a new instance of the view model:

```dart
void refresh() {
  refreshViewModel(viewModel);

  // This will obtain a new instance
  viewModel = getViewModel<MyViewModel>(
    factory: MyViewModelFactory(
      key: "my-key",
    ),
  );
}
``` 