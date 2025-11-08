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


### 1.3 Update Granularity
If you need fine-grained updates based on specific values rather than the entire `ViewModel`, you can use the `ObserverBuilder` and `ObservableValue` combination. This pattern is ideal for scenarios where you want a widget to rebuild only when a particular piece of data changes.

For detailed usage and examples, please refer to the [ObservableValue and ObserverBuilder Documentation](value_observer_doc.md).

### 1.4 API Quick Overview

The methods of ViewModel are straightforward:

| Method                | Description                                            |
|-----------------------|--------------------------------------------------------|
| `watchViewModel<T>() / watchCachedViewModel<T>()` | Listen to a ViewModel and rebuild the UI on changes |
| `readViewModel<T>() / readCachedViewModel<T>()`  | Bind without listening; access data without UI rebuild |
| `ViewModel.readCached<T>() / ViewModel.maybeReadCached<T>()` | Globally access an existing instance (nullable-safe variant) |
| `recycleViewModel()`  | Actively destroy a specific instance                   |
| `listenState()`       | Listen for changes in the state object                 |
| `listen()`            | Listen for `notifyListeners` calls                     |

### 1.5 Terminology

To avoid ambiguity, this documentation consistently uses the following terms:

- Bind: Establish a relationship between a Widget and a `ViewModel` (or between
  one `ViewModel` and another). Both `read*` and `watch*` methods bind; binding
  alone does not imply UI rebuilds.
- Listen: Subscribe to `ViewModel` changes. `watch*` APIs and `*Watcher` widgets
  listen and receive updates when `notifyListeners()` is called.
- Rebuild: When listening is active, the UI rebuilds in response to
  `notifyListeners()`.
- Cached Instance: An already-existing `ViewModel` stored in the cache. Access
  via `readCachedViewModel<T>() / watchCachedViewModel<T>()` or
  `ViewModel.readCached<T>() / ViewModel.maybeReadCached<T>()`.
- Recycle: Actively dispose and remove a `ViewModel` instance from the cache via
  `recycleViewModel()`.

## 2. Basic Usage

This section will guide you through the most basic usage process of `view_model`, serving as the
best starting point to get hands-on with this library.

### 2.1 Adding Dependencies

First, add `view_model` to your project's `pubspec.yaml` file:

```yaml
dependencies:
  flutter:
    sdk: flutter
  view_model: ^0.5.1 # Please use the latest version
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

#### Alternative: ViewModelWatcher (no mixin required)

If you prefer not to mix `ViewModelStateMixin` into your `State`, you can use the convenient `ViewModelWatcher` widget. It internally calls `watchViewModel`, and will rebuild when the `ViewModel` triggers `notifyListeners()`.

```dart
// Example: Using ViewModelWatcher without mixing ViewModelStateMixin
ViewModelWatcher<MySimpleViewModel>(
  factory: MySimpleViewModelFactory(),
  builder: (context, vm) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(vm.message),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: () => vm.updateMessage("Message Updated!"),
          child: const Text('Update Message'),
        ),
      ],
    );
  },
)
```

#### Listening to a cached instance: CachedViewModelWatcher

Use `CachedViewModelWatcher` to listen to an existing `ViewModel` from the cache. It internally uses `watchCachedViewModel`, and rebuilds when `notifyListeners()` is called. To avoid confusion with the widget's `Key`, pass the ViewModel key via `vmKey`, or locate by `tag`.

```dart
// Example: Using CachedViewModelWatcher to bind to an existing instance
CachedViewModelWatcher<MySimpleViewModel>(
  vmKey: "shared-key", // or: tag: "shared-tag"
  builder: (context, vm) {
    return Row(
      children: [
        Expanded(child: Text(vm.message)),
        IconButton(
          onPressed: () => vm.incrementCounter(),
          icon: const Icon(Icons.add),
        ),
      ],
    );
  },
)
```

Note:
- Both `ViewModelWatcher` and `CachedViewModelWatcher` subscribe to updates and rebuild on `notifyListeners()`.
- For one-time reads that do not rebuild, use `readViewModel` or `readCachedViewModel` in your `State`.

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

