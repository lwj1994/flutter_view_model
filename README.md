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
| `ViewModel.read<T>()` | Globally read an existing instance                     |
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

  // 2. Use watchViewModel to get the ViewModel
  // When MyPage is built for the first time, the build() method of MySimpleViewModelFactory will be called to create an instance.
  // When MyPage is disposed, if this viewModel has no other listeners, it will also be disposed.
  MySimpleViewModel get simpleVM =>
      watchViewModel<MySimpleViewModel>(factory: MySimpleViewModelFactory());

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
| `key()`         | `String?` | ✅ Optional       | Provides a unique identifier for the ViewModel. ViewModels with the same key will be automatically shared (recommended for cross-widget/page sharing). | |                              |
| `getTag()`      | `Object?` | ✅                | Add a tag for ViewModel instance. get tag by `viewModel.tag`. and  it's used by find ViewModel by `watchViewModel(tag:tag)`.                           |

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
  String? key() => "user-profile";
}
```

### 3.2 watchViewModel

`watchViewModel<T>()` is one of the core methods, used to: obtain or create a ViewModel instance and
automatically trigger `setState()` to rebuild the Widget when it changes.

```dart
VM watchViewModel<VM extends ViewModel>({
  ViewModelFactory<VM>? factory,
  String? key,
  Object? tag,
});
```

| Parameter Name | Type                    | Optional | Description                                                                                                                                           |
|----------------|-------------------------|----------|-------------------------------------------------------------------------------------------------------------------------------------------------------|
| `factory`      | `ViewModelFactory<VM>?` | ✅        | Provides the construction method for the ViewModel. Optional; if an existing instance is not found in the cache, it will be used to create a new one. |
| `key`          | `String?`               | ✅        | Specifies a unique key to support sharing the same ViewModel instance. First, it tries to find an instance with the same key in the cache.            |
| `tag`          | `Object?`               | ✅        | Add a tag for ViewModel instance. get tag by `viewModel.tag`. and  it's used by find ViewModel by `watchViewModel(tag:tag)`.                          |

__🔍 Lookup Logic Priority (Important)__
The internal lookup and creation logic of `watchViewModel` is as follows (executed in priority
order):

1. If a key is passed in:
    * First, attempt to find an instance with the same key in the cache.
    * If a factory exists, use the factory to get a new instance.
    * If no factory is found and no instance is found, an error will be thrown.
2. If a tag is passed in, attempt to find the latest created instance which has the same tag
   in the cache.
3. If nothing passed in, attempt to find the latest created instance of this type
   in the cache.

> __⚠️ If no ViewModel instance of the specified type is found, an error will be thrown. Ensure
that the ViewModel has been correctly created and registered before use.__

✅ Once an instance is found, `watchViewModel` will automatically register for listening and call
`setState()` to rebuild the current Widget when its state changes.

### 3.3 readViewModel

It has the same parameters as `watchViewModel`, but it does not trigger Widget rebuilding. It is
suitable for scenarios where you need to read the ViewModel state or perform operations once.

### 3.4 ViewModel Lifecycle

- Both `watchViewModel` and `readViewModel` will bind to the ViewModel.
- When no Widget is bound to the ViewModel, it will be automatically destroyed.


### 3.5 ViewModel-to-ViewModel Access

ViewModels can access other ViewModels using `readViewModel` and `watchViewModel`:

- **`readViewModel`**: Access another ViewModel without reactive connection
- **`watchViewModel`**: Create reactive dependency - automatically notifies when the watched ViewModel changes

```dart
class UserProfileViewModel extends ViewModel {
  void loadData() {
    // One-time access without listening
    final authVM = readViewModel<AuthViewModel>();
    if (authVM?.isLoggedIn == true) {
      _fetchProfile(authVM!.userId);
    }
  }
  
  void setupReactiveAuth() {
    // Reactive access - auto-updates when auth changes
    final authVM = watchViewModel<AuthViewModel>();
    // This ViewModel will be notified when authVM changes
  }
  
  @override
  void onDependencyNotify(ViewModel viewModel) {
    // Called when watched ViewModels change
    if (viewModel is AuthViewModel) {
      // React to auth changes
      _handleAuthChange(viewModel);
    }
  }
  
  void manualListening() {
    final authVM = readViewModel<AuthViewModel>();
    // You can also manually listen to any ViewModel
    authVM?.listen(() {
      // Custom listener logic
      _handleAuthChange(authVM);
    });
  }
}
```

**Note**: 
- ViewModel-to-ViewModel `watchViewModel` does not create listening relationships between ViewModels themselves, but allows the calling ViewModel to react to changes in the watched ViewModel.
- When using `watchViewModel`, you'll receive `onDependencyNotify` callbacks when the watched ViewModel changes.
- You can also manually call `vm.listen()` for custom listening logic.



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

  MyCounterViewModel get counterVM =>
      watchViewModel<MyCounterViewModel>(
          factory: MyCounterViewModelFactory(initialCount: 10)); // You can pass an initial value

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

