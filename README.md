# view_model

[![Pub Version](https://img.shields.io/pub/v/view_model)](https://pub.dev/packages/view_model) [![Codecov (with branch)](https://img.shields.io/codecov/c/github/lwj1994/view_model/main)](https://app.codecov.io/gh/lwj1994/view_model/tree/main)

[中文文档](README_ZH.md) <!-- Assuming you'll create/link a Chinese version -->

> I sincerely thank [Miolin](https://github.com/Miolin) for entrusting me with the permissions for the [ViewModel](https://pub.dev/packages/view_model)
> package and transferring its ownership. This support is invaluable, and I'm excited to drive its continued development.

---

`view_model` is a lightweight Flutter state management library designed to provide a concise and efficient solution.

## 1. Basic Introduction

### 1.1 What is ViewModel?

`ViewModel` is a lightweight state management tool based on `StreamController` and `setState`. It doesn't strictly adhere to the ViewModel definition in the MVVM architecture but rather focuses on serving as a container for a Widget's state and business logic.

### 1.2 Core Features

*   **Lightweight and Easy to Use**: Designed with minimal dependencies and a very simple API, making it quick to learn and minimally intrusive.
*   **Automatic Resource Management**: When no Widget is `watch`ing (listening to) a `ViewModel` instance, that instance will automatically call its `dispose` method and be destroyed, effectively preventing memory leaks.
*   **Convenient Sharing**: Supports sharing the same `ViewModel` instance across multiple Widgets with efficient O(1) time complexity for lookup.

> **Important Note**: `ViewModel` only supports binding to `StatefulWidget`. This is because `StatelessWidget` does not have an independent lifecycle, which is necessary for `ViewModel`'s automatic disposal and state listening mechanisms.

> * `watchViewModel` and `readViewModel` will bind ViewModel
> * when no one bind viewModel, viewModel will be disposed automatically

### 1.3 API Overview

The methods for ViewModel are straightforward:

| Method                    | Description                                       |
| :------------------------ | :------------------------------------------------ |
| `watchViewModel<T>()`     | Binds a ViewModel and automatically refreshes the UI. |
| `readViewModel<T>()`      | Binds a ViewModel but does not trigger a UI refresh. |
| `ViewModel.read<T>()`     | Globally reads an existing instance.              |
| `recycleViewModel()`      | Actively disposes of a specific instance.         |
| `listenState()`           | Listens for changes to the state object.          |
| `listen()`                | Listens for `notifyListeners` calls.              |

## 2. Basic Usage

This section will guide you through the most basic usage of a stateless `ViewModel` with `view_model`. This is the best starting point for getting acquainted with this library.

### 2.1 Add Dependency

First, add `view_model` to your project's `pubspec.yaml` file:

```yaml
dependencies:
  flutter:
    sdk: flutter
  view_model: ^0.4.2 # Please use the latest version
```

Then run `flutter pub get`.

### 2.2 Create ViewModel

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
    notifyListeners(); // Notify listeners that data has been updated
  }

  void incrementCounter() {
    _counter++;
    notifyListeners(); // Notify listeners that data has been updated
  }

  @override
  void dispose() {
    // Clean up resources here, e.g., close StreamControllers, etc.
    debugPrint('MySimpleViewModel disposed');
    super.dispose();
  }
}
```

In this example, `MySimpleViewModel` manages a `message` string and a `counter` integer. When these values are updated through its methods, `notifyListeners()` is called to inform any Widgets listening to this `ViewModel` to rebuild.

### 2.3 Create ViewModelFactory

A `ViewModelFactory` is responsible for the instantiation of a `ViewModel`. Each `ViewModel` type typically requires a corresponding `Factory`.

```dart
import 'package:view_model/view_model.dart';
// Assume MySimpleViewModel is defined as above

class MySimpleViewModelFactory with ViewModelFactory<MySimpleViewModel> {
  @override
  MySimpleViewModel build() {
    // Return a new instance of MySimpleViewModel
    return MySimpleViewModel();
  }
}
```

### 2.4 Use ViewModel in a Widget

In your `StatefulWidget`, integrate and use `ViewModel` by mixing in `ViewModelStateMixin`.

1.  **Mix in `ViewModelStateMixin`**: Let your `State` class mix in `ViewModelStateMixin<YourWidget>`.
2.  **Use `watchViewModel`**: In the `State`, use the `watchViewModel` method to get or create a `ViewModel` instance. This method automatically handles the `ViewModel`'s lifecycle and dependencies.

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
    with ViewModelStateMixin<MyPage> { // 1. Mix in the Mixin

  // 2. Use watchViewModel to get the ViewModel
  // When MyPage is first built, MySimpleViewModelFactory's build() method will be called to create an instance.
  // When MyPage is disposed, if this viewModel has no other listeners, it will also be disposed.
  MySimpleViewModel get simpleVM =>
      watchViewModel<MySimpleViewModel>(factory: MySimpleViewModelFactory());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(simpleVM.message)), // Directly access ViewModel's property
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text('Button pressed: ${simpleVM.counter} times'), // Access ViewModel's property
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                simpleVM.updateMessage("Message Updated!"); // Call ViewModel's method
              },
              child: const Text('Update Message'),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => simpleVM.incrementCounter(), // Call ViewModel's method
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
```

### 2.5 Listening to ViewModel Notifications

Besides the UI automatically responding to `ViewModel` updates, you can also use the `listen` method to listen for its `notifyListeners()` calls and perform side effects, such as showing a `SnackBar`, navigating, etc.

```dart
// In the State's initState or other appropriate method
late VoidCallback _disposeViewModelListener;

@override
void initState() {
  super.initState();

  // Get the ViewModel instance (usually obtained once in initState, or accessed via a getter)
  final myVm = watchViewModel<MySimpleViewModel>(factory: MySimpleViewModelFactory());

  _disposeViewModelListener = myVm.listen(onChanged: () {
    print('MySimpleViewModel called notifyListeners! Current counter: ${myVm.counter}');
    // Example: ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Action performed!')));
  });
}

@override
void dispose() {
  _disposeViewModelListener(); // Clean up the listener to prevent memory leaks
  super.dispose();
}
```

**Note**: `listen` returns a `VoidCallback` used to cancel the subscription. Ensure you call it in the `State`'s `dispose` method.

## 3. Detailed Parameter Explanation

### 3.1 ViewModelFactory

`ViewModelFactory<T>` is a factory class used to create, configure, and identify ViewModel instances. It is used via a mixin (`with`).

| Method/Property | Type      | Optional | Description                                                                       |
| :-------------- | :-------- | :------- | :-------------------------------------------------------------------------------- |
| `build()`       | `T`       | ❌ Req.  | Factory method to create ViewModel instances. Constructor arguments are usually passed here. |
| `key()`         | `String?` | ✅ Opt.  | Provides a unique identifier for the ViewModel. ViewModels with the same key will be automatically shared (recommended for cross-widget/page sharing). |

```dart
class MyViewModelFactory with ViewModelFactory<MyViewModel> {
  // Your custom parameters, usually passed to MyViewModel
  final String initialName;

  MyViewModelFactory({required this.initialName});

  @override
  MyViewModel build() {
    return MyViewModel(name: initialName);
  }

  /// Key for sharing the ViewModel. The key is unique; only one ViewModel instance will be created per key.
  /// If the key is null, it is not shared.
  @override
  String? key() => "user-profile";
}
```

### 3.2 watchViewModel

`watchViewModel<T>()` is one of the core methods. Its role is to: Get or create a ViewModel instance, and automatically trigger `setState()` to rebuild the Widget when it changes.

```dart
VM watchViewModel<VM extends ViewModel>({
  ViewModelFactory<VM>? factory,
  String? key,
});
```

| Parameter Name | Type                    | Optional | Description                                                                     |
| :------------- | :---------------------- | :------- | :------------------------------------------------------------------------------ |
| `factory`      | `ViewModelFactory<VM>?` | ✅       | Provides how the ViewModel is built. Optional; used to create a new instance if one isn't found in the cache. |
| `key`          | `String?`               | ✅       | Specifies a unique key, supporting sharing the same ViewModel instance. Prioritizes finding an instance in the cache. |

__🔍 Lookup Logic Priority (Important)__
The internal lookup and creation logic of `watchViewModel` is as follows (executed in order of priority):

1.  If a `key` is provided:
  *   It first tries to find an instance with the same `key` from the cache.
  *   If not found, it calls `factory.build()` to create a new instance and caches it.
2.  Tries to find the most recently created instance from the cache (if no key is provided or the key lookup failed without a factory).
3.  **⚠️If an instance of the specified ViewModel type cannot be found, an exception will be thrown. Please ensure that the ViewModel has been correctly created and registered before use.**

✅ Once an instance is found, `watchViewModel` automatically registers a listener and calls `setState()` to rebuild the current Widget when its state changes.

### 3.3 readViewModel

The parameters are the same as `watchViewModel`, but the difference is that it will not trigger a Widget rebuild. Suitable for scenarios where you need to read the ViewModel state once or perform an action without rebuilding.

## 4. ViewModel with State (`StateViewModel<S>`)

When your business logic needs to manage a well-defined, structured state object, `StateViewModel<S>` is a more suitable choice. It enforces holding an immutable `state` object and updates the state via a `setState` method.

### 4.1 Define the State Class

First, you need to define a state class. It is strongly recommended that this class be immutable, usually achieved by providing a `copyWith` method.

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

### 4.2 Create a Stateful ViewModel

Inherit from `StateViewModel<S>`, where `S` is the type of your defined state class.

```dart
// example: lib/my_counter_view_model.dart
import 'package:view_model/view_model.dart';
import 'package:flutter/foundation.dart';
import 'my_counter_state.dart'; // Import the state class

class MyCounterViewModel extends StateViewModel<MyCounterState> {
  // The constructor must initialize state via super
  MyCounterViewModel({required MyCounterState initialState}) : super(state: initialState);

  void increment() {
    // Use setState to update the state; it automatically handles notifyListeners
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

In `StateViewModel`, you update the state by calling `setState(newState)`. This method replaces the old state with the new state and automatically notifies all listeners.

### 4.3 Create ViewModelFactory

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
    // Create and return the ViewModel instance in the build method, passing in the initial state
    return MyCounterViewModel(
        initialState: MyCounterState(count: initialCount, statusMessage: "Initialized"));
  }
}
```

### 4.4 Use Stateful ViewModel in a Widget

Using a stateful `ViewModel` in a `StatefulWidget` is very similar to using a stateless `ViewModel`. The main difference is that you can directly access `viewModel.state` to get the current state object.

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
              'Count: ${counterVM.state.count}', // Directly access state's property
              style: Theme
                  .of(context)
                  .textTheme
                  .headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Status: ${counterVM.state.statusMessage}', // Access other properties of state
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

### 4.5 Listening to State Changes (`listenState`)

For `StateViewModel`, in addition to the generic `listen()` method, there is a dedicated `listenState()` method. It allows you to receive the old state and new state when the state object actually changes.

```dart
// In the State's initState or other appropriate method
late VoidCallback _disposeStateListener;

@override
void initState() {
  super.initState();

  final myStateVM = watchViewModel<MyCounterViewModel>(factory: MyCounterViewModelFactory());

  _disposeStateListener = myStateVM.listenState(
    onChanged: (MyCounterState? previousState, MyCounterState currentState) {
      print('State changed! Previous count: ${previousState?.count}, New count: ${currentState.count}');
      print('Message: ${currentState.statusMessage}');
      // Example: ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Count is now ${currentState.count}')));
    }
  );
}

@override
void dispose() {
  _disposeStateListener(); // Clean up the listener
  super.dispose();
}
```

`listenState` also returns a `VoidCallback` to cancel the subscription. Be sure to call it in the `State`'s `dispose` method.

## 5. Other Advanced Usage

### 5.1 Globally Accessing ViewModel Instances

Besides using `watchViewModel()` and `readViewModel()` in a `StatefulWidget`, you can also globally access existing ViewModel instances from anywhere, such as in the business logic layer, route navigation logic, or service modules.

1.  Directly find by type:
    ```dart
    final MyViewModel vm = ViewModel.read<MyViewModel>();
    ```
2.  Find by key:
    ```dart
    final vm = ViewModel.read<MyViewModel>(key: 'user-profile');
    ```

> ⚠️If an instance of the specified ViewModel type cannot be found, an exception will be thrown. Please ensure that the ViewModel has been correctly created and registered before use.

### 5.2 Manually Managing ViewModel Lifecycle

In some advanced scenarios, you might need to explicitly remove (and `dispose`) a `ViewModel` instance from the cache.

*   **`recycleViewModel<T extends ViewModel>(T viewModel)` (in `ViewModelStateMixin`)**
  *   This method immediately removes the specified `viewModel` instance from the internal cache and calls its `dispose()` method.
  *   All places that previously `watch`ed or `read` this instance will, if they try to access it again, recreate or retrieve it according to its `Factory`'s configuration.

```dart
MyComplexViewModel get complexViewModel =>
    watchViewModel<MyComplexViewModel>(
        factory: MyComplexViewModelFactory());

void resetAndRefreshTask() {
  final vmToRecycle = complexViewModel;
  recycleViewModel(vmToRecycle);
  // Accessing complexViewModel again will get a new instance
  print(complexViewModel.state.status); // Assuming it's a StateViewModel
  print(complexViewModel.someProperty); // Assuming it's a ViewModel
}
```

**Use `recycleViewModel` with caution**: Improper use can lead to unexpected behavior in other Widgets that are using the `ViewModel`.

## 6. Regarding Local Refresh

`view_model` itself does not directly handle the granularity of UI "local refresh." When a `ViewModel` calls `notifyListeners()`, the `build` method of all `StatefulWidget`s that `watch`ed that `ViewModel` will be called. The Flutter framework itself performs efficient Widget Diffing, only re-rendering the parts that actually changed.

Typically, relying on this Flutter mechanism is efficient enough. A component's `build` method mainly describes the UI configuration, and calling it frequently does not inherently cause significant performance overhead unless the `build` method contains very time-consuming computations.

If finer-grained control is indeed needed, you can use Flutter's built-in `ValueListenableBuilder` in combination. Wrap a specific value in your `ViewModel` with a `ValueNotifier`, update it within the `ViewModel`, and then use `ValueListenableBuilder` in the UI to listen to this `ValueNotifier`.

```dart
// In ViewModel:
class MyFineGrainedViewModel extends ViewModel {
  final ValueNotifier<String> specificData = ValueNotifier("Initial");

  void updateSpecificData(String newData) {
    specificData.value = newData;
    // If you also need to notify listeners of the entire ViewModel, you can additionally call notifyListeners()
  }
}
```

```dart
// In Widget's build method:
Widget buildValueListenableBuilder() {
  // Assume viewModel is an instance of MyFineGrainedViewModel
  final viewModel = watchViewModel<MyFineGrainedViewModel>(factory: MyFineGrainedViewModelFactory());

  return ValueListenableBuilder<String>(
    valueListenable: viewModel.specificData,
    builder: (context, value, child) {
      return Text(value); // This Text only rebuilds when specificData changes
    },
  );
}
```