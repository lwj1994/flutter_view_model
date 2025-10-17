<p align="center">
  <img src="https://youke1.picui.cn/s1/2025/10/17/68f20115693e6.png" alt="ViewModel Logo" height="96" />
</p>

# view_model

[![Pub Version](https://img.shields.io/pub/v/view_model)](https://pub.dev/packages/view_model) [![Codecov (with branch)](https://img.shields.io/codecov/c/github/lwj1994/flutter_view_model/main)](https://app.codecov.io/gh/lwj1994/flutter_view_model/tree/main)

[ChangeLog](CHANGELOG.md)

[English Doc](README.md) | [中文文档](README_ZH.md)
> Thank [Miolin](https://github.com/Miolin) for transferring the permission of
> the [view_model](https://pub.dev/packages/view_model) package to me.

---

## 1. Basic Introduction
### 1.1 What is ViewModel?

`view_model` is the simplest state management solution for Flutter applications.

### 1.2 Core Features

This library extends the traditional ViewModel pattern with Flutter-specific enhancements:

- **Lightweight and Easy to Use**: Minimal dependencies and extremely simple APIs for quick integration
- **Automatic Resource Management**: ViewModels are automatically disposed when no Widgets are bound to them, preventing memory leaks
- **Efficient Instance Sharing**: Share the same ViewModel instance across multiple Widgets with O(1) lookup performance
- **Widget Lifecycle Integration**: Seamlessly integrates with Flutter's Widget lifecycle through `ViewModelStateMixin`

> **Important Note**: `ViewModel` only supports binding to `StatefulWidget`. This is because
`StatelessWidget` has no independent lifecycle, making it unable to support the automatic
> destruction and state listening mechanisms of `ViewModel`.

> * `watchViewModel` and `readViewModel` will bind to the ViewModel.
> * When no Widget is bound to the ViewModel, the ViewModel will be automatically destroyed.

### 1.3 Don't support Fine-grained Updates

`view_model` deliberately does not provide fine-grained update mechanisms like Observer patterns, and here's why:

https://github.com/lwj1994/flutter_view_model/issues/13

### 1.4 API Quick Overview

The methods of ViewModel are straightforward:

| Method                | Description                                            |
|-----------------------|--------------------------------------------------------|
| `watchViewModel<T>()` | Bind to the ViewModel and automatically refresh the UI |
| `readViewModel<T>()`  | Bind to the ViewModel without triggering UI refresh    |
| `ViewModel.readCached<T>()` | Globally read an existing instance                     |
| `recycleViewModel()`  | Actively destroy a specific instance                   |
| `listenState()`       | Listen for changes in the state object                 |
| `listen()`            | Listen for `notifyListeners` calls                     |

## 2. Basic Usage

This section will guide you through the most basic usage process of `view_model`, serving as the
best starting point to get hands-on with this library.

### 2.1 Adding Dependencies

First, add `view_model` to your project's `pubspec.yaml` file:

```yaml
dependencies:
  flutter:
    sdk: flutter
  view_model: ^0.4.6 # Please use the latest version
```

Then run `flutter pub get`.

### 2.2 Creating a ViewModel

Inherit from the `ViewModel` class to create your business logic unit.

```dart
import 'package:view_model/view_model.dart';
import 'package:flutter/foundation.dart'; // For debugPrint

class MySimpleViewModel extends ViewModel {
  String _message = "Initial Message";
  int _counter = 0;

  String get message => _message;

  int get counter => _counter;

  void updateMessage(String newMessage) {
    _message = newMessage;
    notifyListeners(); // Notify listeners that the data has been updated
  }

  void incrementCounter() {
    _counter++;
    notifyListeners(); // Notify listeners that the data has been updated
  }

  @override
  void dispose() {
    // Clean up resources here, such as closing StreamControllers, etc.
    debugPrint('MySimpleViewModel disposed');
    super.dispose();
  }
}
```

In this example, `MySimpleViewModel` manages a `message` string and a `counter` integer. When these
values are updated through its methods, `notifyListeners()` is called to inform any Widgets
listening to this `ViewModel` to rebuild.

### 2.3 Creating a ViewModelFactory

`ViewModelFactory` is responsible for instantiating `ViewModel`. Each `ViewModel` type typically
requires a corresponding `Factory`.

```dart
import 'package:view_model/view_model.dart';
// Assume MySimpleViewModel is defined as above

class MySimpleViewModelFactory with ViewModelFactory<MySimpleViewModel> {
  @override
  MySimpleViewModel build() {
    // Return a new MySimpleViewModel instance
    return MySimpleViewModel();
  }
}
```

### 2.4 Using ViewModel in Widgets

In your `StatefulWidget`, integrate and use `ViewModel` by mixing in `ViewModelStateMixin`.

1. **Mix in `ViewModelStateMixin`**: Make your `State` class mix in
   `ViewModelStateMixin<YourWidget>`.
2. **Use `watchViewModel`**: Obtain or create a `ViewModel` instance through the `watchViewModel`
   method in `State`. This method automatically handles the lifecycle and dependencies of the
   `ViewModel`.

```dart
import 'package:flutter/material.dart';
import 'package:view_model/view_model.dart';

// Assume MySimpleViewModel and MySimpleViewModelFactory are defined

class MyPage extends StatefulWidget {
  const MyPage({super.key});

  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage>
    with ViewModelStateMixin<MyPage> {
  // 1. Mix in the Mixin
  late final MySimpleViewModel simpleVM;

  @override
  void initState() {
    super.initState();
    // 2. Use watchViewModel to create and get the ViewModel
    // When MyPage is built for the first time, the build() method of MySimpleViewModelFactory will be called to create an instance.
    // When MyPage is disposed, if this viewModel has no other listeners, it will also be disposed.
    simpleVM =
        watchViewModel<MySimpleViewModel>(factory: MySimpleViewModelFactory());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(simpleVM.message)), // Directly access the ViewModel's properties
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text('Button pressed: ${simpleVM.counter} times'), // Access the ViewModel's properties
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                simpleVM.updateMessage("Message Updated!"); // Call the ViewModel's method
              },
              child: const Text('Update Message'),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => simpleVM.incrementCounter(), // Call the ViewModel's method
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
```

### 2.5 Listening to ViewModel Notifications

In addition to the UI automatically responding to `ViewModel` updates, you can also listen to its
`notifyListeners()` calls through the `listen` method and perform side effects, such as displaying a
`SnackBar` or navigation.

```dart
// In the initState of State or another appropriate method
late VoidCallback _disposeViewModelListener;

@override
void initState() {
  super.initState();

  // Get the ViewModel instance (usually obtained once in initState or via a getter)
  final myVm = watchViewModel<MySimpleViewModel>(factory: MySimpleViewModelFactory());

  _disposeViewModelListener = myVm.listen(onChanged: () {
    print('MySimpleViewModel called notifyListeners! Current counter: ${myVm.counter}');
    // For example: ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Action performed!')));
  });
}

@override
void dispose() {
  _disposeViewModelListener(); // Clean up the listener to prevent memory leaks
  super.dispose();
}
```

**Note**: `listen` returns a `VoidCallback` for canceling the listener. Ensure you call it in the
`dispose` method of `State`.

## 3. Detailed Parameter Explanation

### 3.1 ViewModelFactory

`ViewModelFactory<T>` is a factory class used to create, configure, and identify ViewModel
instances. It is used via mixing (with).

| Method/Property | Type      | Optional         | Description                                                                                                                                            |
|-----------------|-----------|------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------|
| `build()`       | `T`       | ❌ Must implement | The factory method to create a ViewModel instance. Typically, constructor parameters are passed here.                                                  |
| `key()`         | `Object?` | ✅ Optional       | Provides a unique identifier for the ViewModel. ViewModels with the same key will be automatically shared (recommended for cross-widget/page sharing). |
| `getTag()`      | `Object?` | ✅                | Add a tag for ViewModel instance. get tag by `viewModel.tag`. and  it's used by find ViewModel by `watchViewModel(tag:tag)`.                           |

> **Note**: If you use a custom object as a key, you must properly override the `==` operator and `hashCode` to ensure that the ViewModel instance can be correctly retrieved from the cache.

```dart
class MyViewModelFactory with ViewModelFactory<MyViewModel> {
  // Your custom parameters, usually passed to MyViewModel
  final String initialName;

  MyViewModelFactory({required this.initialName});

  @override
  MyViewModel build() {
    return MyViewModel(name: initialName);
  }

  /// The key for sharing the ViewModel. The key is unique, and only one ViewModel instance will be created for the same key.
  /// If the key is null, no sharing will occur.
  @override
  Object? key() => "user-profile";
}
```

### 3.2 API Reference & Migration Guide

With the latest update, the API has been refined for clarity and predictability. Here’s a breakdown of the core methods and how to migrate your existing code.

#### Creating and Watching a New Instance

**`watchViewModel<VM extends ViewModel>({required ViewModelFactory<VM> factory})`**

This is now the **only** method to create a new `ViewModel` instance. It requires a `factory` to construct the `ViewModel`.

- **Usage**: Call this when a widget needs to create and own a `ViewModel`.
- **Migration**: If you were previously using `watchViewModel` to both create and retrieve instances, your code for creating instances remains the same. Ensure you always provide a `factory`.

```dart
// Before
// Might create or retrieve a cached instance
final myVM = watchViewModel<MyViewModel>(factory: MyViewModelFactory());

// After
// Always creates a new instance
final myVM = watchViewModel<MyViewModel>(factory: MyViewModelFactory());
```

#### Reading a New Instance Without Listening

**`readViewModel<VM extends ViewModel>({required ViewModelFactory<VM> factory})`**

This method is used to retrieve or create a `ViewModel` instance but **does not** subscribe the widget to its updates. It's useful for one-time actions or data retrieval.

- **Behavior**:
  - If the `factory` provides a `key`, it will first attempt to find an instance with that `key` in the cache. If not found, it creates a new instance and caches it based on the `isSingleton` setting.
  - If the `factory` does not provide a `key`, it will create a new, **non-shared** instance.
- **Usage**: When you need to access a `ViewModel`'s methods or initial state without causing the widget to rebuild on its subsequent changes.

```dart
// If MyViewModelFactory provides a key, it may retrieve a cached instance.
// Otherwise, it always creates a new instance.
final myVM = readViewModel<MyViewModel>(factory: MyViewModelFactory());
```

#### Watching a Cached Instance

**`watchCachedViewModel<VM extends ViewModel>({Object? key, Object? tag})`**

Use this method to find and listen to an **existing** `ViewModel` instance from the cache. It will **throw an error** if the instance is not found.

- **Usage**: In a widget that needs to react to changes in a shared `ViewModel` that was created elsewhere.
- **Lookup Priority**: `key` -> `tag` -> `Type`.
- **Migration**: Replace `watchViewModel(key: ...)` or `watchViewModel(tag: ...)` with `watchCachedViewModel` when you intend to retrieve a cached instance.

```dart
// Before
// Ambiguous: could create or retrieve
final myVM = watchViewModel<MyViewModel>(key: "shared-key");

// After
// Explicit: retrieves a cached instance or throws
final myVM = watchCachedViewModel<MyViewModel>(key: "shared-key");
```

#### Reading a Cached Instance

**`readCachedViewModel<VM extends ViewModel>({Object? key, Object? tag})`**

Use this to find and read an **existing** `ViewModel` without subscribing to updates. It will **throw an error** if not found.

- **Usage**: For one-time access to a shared `ViewModel`'s state or methods.
- **Migration**: Replace `readViewModel(key: ...)` or `readViewModel(tag: ...)` with `readCachedViewModel`.

```dart
// Before
final myVM = readViewModel<MyViewModel>(key: "shared-key");

// After
// Explicit: retrieves a cached instance or throws
final myVM = readCachedViewModel<MyViewModel>(key: "shared-key");
```

#### Safely Watching a Cached Instance (Nullable)

**`maybeWatchCachedViewModel<VM extends ViewModel>({Object? key, Object? tag})`**

A safe alternative to `watchCachedViewModel`. It returns `null` instead of throwing an error if the `ViewModel` is not found in the cache.

- **Usage**: When a shared `ViewModel` is optional.

```dart
// Retrieves a cached instance or returns null
final myVM = maybeWatchCachedViewModel<MyViewModel>(key: "optional-key");
if (myVM != null) {
  // ... use myVM
}
```

#### Safely Reading a Cached Instance (Nullable)

**`maybeReadCachedViewModel<VM extends ViewModel>({Object? key, Object? tag})`**

A safe alternative to `readCachedViewModel`. It returns `null` if the `ViewModel` is not found.

- **Usage**: For optional, one-time access to a shared `ViewModel`.

```dart
// Retrieves a cached instance or returns null
final myVM = maybeReadCachedViewModel<MyViewModel>(key: "optional-key");
// ...
```

### 3.3 ViewModel Lifecycle

- `watchViewModel`, `readViewModel`, `watchCachedViewModel`, and `readCachedViewModel` will bind the widget to the ViewModel.
- When no Widget is bound to the ViewModel, it will be automatically destroyed.

### 3.4 Accessing ViewModels from other ViewModels

ViewModels can access other ViewModels using the same API:

- **`readCachedViewModel`**: Access another ViewModel without creating a reactive connection.
- **`watchCachedViewModel`**: Create a reactive dependency - automatically get notified when the watched ViewModel changes.

When a ViewModel (the `HostVM`) accesses another ViewModel (the `SubVM`) via `watchCachedViewModel`, the framework automatically binds the `SubVM`'s lifecycle to the `HostVM`'s UI observer (i.e., the `State` object of the `StatefulWidget`).

This means both the `SubVM` and the `HostVM` are directly managed by the lifecycle of the same `State` object. When this `State` object is disposed, if neither the `SubVM` nor the `HostVM` has other observers, they will be disposed of together automatically.

This mechanism ensures clear dependency relationships between ViewModels and enables efficient, automatic resource management.

```dart
class UserProfileViewModel extends ViewModel {
  void loadData() {
    // One-time access, no listening
    final authVM = readCachedViewModel<AuthViewModel>();
    if (authVM?.isLoggedIn == true) {
      _fetchProfile(authVM!.userId);
    }
  }
  
  void setupReactiveAuth() {
    // Reactive access - automatically updates when auth changes
    final authVM = watchCachedViewModel<AuthViewModel>();
    // This ViewModel will be notified when authVM changes
  }
    
  void manualListening() {
    final authVM = readCachedViewModel<AuthViewModel>();
    // You can also manually listen to any ViewModel
    authVM?.listen(() {
      // Custom listening logic
      _handleAuthChange(authVM);
    });
  }
}
```

## 4. Stateful ViewModel (`StateViewModel<S>`)

When your business logic needs to manage a clear, structured state object, `StateViewModel<S>` is a
more suitable choice. It enforces holding an immutable `state` object and updates the state through
the `setState` method.

### 4.1 Defining the State Class

First, you need to define a state class. It is strongly recommended that this class is immutable,
typically achieved by providing a `copyWith` method.

```dart
// example: lib/my_counter_state.dart
import 'package:flutter/foundation.dart';

@immutable // Recommended to mark as immutable
class MyCounterState {
  final int count;
  final String statusMessage;

  const MyCounterState({this.count = 0, this.statusMessage = "Ready"});

  MyCounterState copyWith({int? count, String? statusMessage}) {
    return MyCounterState(
      count: count ?? this.count,
      statusMessage: statusMessage ?? this.statusMessage,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is MyCounterState &&
              runtimeType == other.runtimeType &&
              count == other.count &&
              statusMessage == other.statusMessage;

  @override
  int get hashCode => count.hashCode ^ statusMessage.hashCode;

  @override
  String toString() => 'MyCounterState{count: $count, statusMessage: $statusMessage}';
}
```

### 4.2 Creating a Stateful ViewModel

Inherit from `StateViewModel<S>`, where `S` is the type of the state class you defined.

```dart
// example: lib/my_counter_view_model.dart
import 'package:view_model/view_model.dart';
import 'package:flutter/foundation.dart';
import 'my_counter_state.dart'; // Import the state class

class MyCounterViewModel extends StateViewModel<MyCounterState> {
  // The constructor must initialize the state via super
  MyCounterViewModel({required MyCounterState initialState}) : super(state: initialState);

  void increment() {
    // Use setState to update the state, which will automatically handle notifyListeners
    setState(state.copyWith(count: state.count + 1, statusMessage: "Incremented"));
  }

  void decrement() {
    if (state.count > 0) {
      setState(state.copyWith(count: state.count - 1, statusMessage: "Decremented"));
    } else {
      setState(state.copyWith(statusMessage: "Cannot decrement below zero"));
    }
  }

  void reset() {
    // You can directly replace the old state with a new State instance
    setState(const MyCounterState(count: 0, statusMessage: "Reset"));
  }

  @override
  void dispose() {
    debugPrint('Disposed MyCounterViewModel with state: $state');
    super.dispose();
  }
}
```

In `StateViewModel`, you update the state by calling `setState(newState)`. This method replaces the
old state with the new one and automatically notifies all listeners.

### 4.3 Creating a ViewModelFactory

Create a corresponding `Factory` for your `StateViewModel`.

```dart
// example: lib/my_counter_view_model_factory.dart
import 'package:view_model/view_model.dart';
import 'my_counter_state.dart';
import 'my_counter_view_model.dart';

class MyCounterViewModelFactory with ViewModelFactory<MyCounterViewModel> {
  final int initialCount;

  MyCounterViewModelFactory({this.initialCount = 0});

  @override
  MyCounterViewModel build() {
    // Create and return the ViewModel instance in the build method, passing the initial state
    return MyCounterViewModel(
        initialState: MyCounterState(count: initialCount, statusMessage: "Initialized"));
  }
}
```

### 4.4 Using Stateful ViewModel in Widgets

Using a stateful `ViewModel` in a `StatefulWidget` is very similar to using a stateless `ViewModel`,
with the main difference being that you can directly access `viewModel.state` to obtain the current
state object.

```dart
// example: lib/my_counter_page.dart
import 'package:flutter/material.dart';
import 'package:view_model/view_model.dart';
import 'my_counter_view_model.dart';
import 'my_counter_view_model_factory.dart';
// MyCounterState will be referenced internally by MyCounterViewModel

class MyCounterPage extends StatefulWidget {
  const MyCounterPage({super.key});

  @override
  State<MyCounterPage> createState() => _MyCounterPageState();
}

class _MyCounterPageState extends State<MyCounterPage>
    with ViewModelStateMixin<MyCounterPage> {
  late final MyCounterViewModel counterVM;

  @override
  void initState() {
    super.initState();
    counterVM = watchViewModel<MyCounterViewModel>(
        factory: MyCounterViewModelFactory(initialCount: 10)); // You can pass an initial value
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Stateful ViewModel Counter')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'Count: ${counterVM.state.count}', // Directly access the state's properties
              style: Theme
                  .of(context)
                  .textTheme
                  .headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Status: ${counterVM.state.statusMessage}', // Access other properties of the state
              style: Theme
                  .of(context)
                  .textTheme
                  .titleMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: () => counterVM.increment(),
            tooltip: 'Increment',
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            onPressed: () => counterVM.decrement(),
            tooltip: 'Decrement',
            child: const Icon(Icons.remove),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.extended(
            onPressed: () => counterVM.reset(),
            tooltip: 'Reset',
            icon: const Icon(Icons.refresh),
            label: const Text("Reset"),
          ),
        ],
      ),
    );
  }
}
```

---

## 5. DefaultViewModelFactory Quick Factory

### 5.1 When to Use

For simple ViewModels that do not require complex construction logic, you can use this factory
directly.

### 5.2 Usage

```dart

final factory = DefaultViewModelFactory<MyViewModel>(
  builder: () => MyViewModel(),
  isSingleton: true, // optional
);
```

### 5.3 Parameters

- `builder`: Function to create the ViewModel instance.
- `key`: Custom key for singleton instance sharing.
- `tag`: Custom tag for identifying the ViewModel.
- `isSingleton`: Whether to use singleton mode. This is just a convenient way to set a unique key for you. Note that the priority is lower than the key parameter.

### 5.4 Example

```dart

final factory = DefaultViewModelFactory<CounterViewModel>(
  builder: () => CounterViewModel(),
);
final sharedFactory = DefaultViewModelFactory<CounterViewModel>(
  builder: () => CounterViewModel(),
  key: 'global-counter',
);
```

This factory is especially useful for simple ViewModels that do not require complex construction
logic.

---

## 6. DevTools Extension

The `view_model` package includes a powerful DevTools extension that provides real-time monitoring
and debugging capabilities for your ViewModels during development.

create `devtools_options.yaml` in root directory of project.

```yaml
description: This file stores settings for Dart & Flutter DevTools.
documentation: https://docs.flutter.dev/tools/devtools/extensions#configure-extension-enablement-states
extensions:
  - view_model: true
```

![](https://i.imgur.com/5itXPYD.png)
![](https://imgur.com/83iOQhy.png)

