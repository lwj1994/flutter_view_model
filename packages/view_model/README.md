<p align="center">
  <img src="https://lwjlol-images.oss-cn-beijing.aliyuncs.com/logo.png" alt="ViewModel Logo" height="96" />
</p>

# view_model

> The missing ViewModel in Flutter — Everything is ViewModel.

| Package | Version |
| :--- | :--- |
| **view_model** | [![Pub Version](https://img.shields.io/pub/v/view_model)](https://pub.dev/packages/view_model) |
| **view_model_annotation** | [![Pub Version](https://img.shields.io/pub/v/view_model_annotation)](https://pub.dev/packages/view_model_annotation) |
| **view_model_generator** | [![Pub Version](https://img.shields.io/pub/v/view_model_generator)](https://pub.dev/packages/view_model_generator) |

[![Codecov](https://img.shields.io/codecov/c/github/lwj1994/flutter_view_model/main)](https://app.codecov.io/gh/lwj1994/flutter_view_model/tree/main)

[ChangeLog](https://github.com/lwj1994/flutter_view_model/blob/main/packages/view_model/CHANGELOG.md) | [中文文档](https://github.com/lwj1994/flutter_view_model/blob/main/README_ZH.md)


## The Problem

In Flutter, managing state often comes with two major headaches:
1.  **Boilerplate**: You have to write a lot of code just to "provide" your state classes to widgets (like `BlocProvider`, `ChangeNotifierProvider`).
2.  **Context Hell**: Your logic classes often need `BuildContext` to access other logic, making them hard to test and dependent on the UI tree.

## The Solution

**view_model** solves these problems by decoupling your business logic from the widget tree.

*   **Isolation by Default**: Unlike global-state solutions (like Riverpod), ViewModels are **not shared** by default. Each widget gets its own isolated instance. No more accidental state pollution!
*   **Explicit Sharing**: Powerfully share state *only when you intend to* using a `key`.
*   **Zero Boilerplate**: No need to manually provide ViewModels at the top of your tree.
*   **No Context needed**: ViewModels can talk to each other without `BuildContext`.
*   **Automatic Lifecycle**: ViewModels are automatically created when used, and disposed when no longer needed.

## Installation

```yaml
dependencies:
  view_model: ^latest_version

dev_dependencies:
  build_runner: ^latest_version
  view_model_generator: ^latest_version # Optional, easier to use
```

## Quick Start

### 1. Define a ViewModel

Create a class extending `ViewModel`. Use `update()` to notify widgets of changes.

```dart
class CounterViewModel extends ViewModel {
  int count = 0;

  void increment() {
    update(() => count++);
  }
}
```

### 2. Create a Provider

Define a global provider. This is how widgets find your ViewModel.

```dart
final counterProvider = ViewModelProvider<CounterViewModel>(
  builder: () => CounterViewModel(),
);
```

*(Tip: Use `view_model_generator` to skip this step!)*

### 3. Use in Widget

Use `ViewModelStateMixin` in your `StatefulWidget`.

```dart
class CounterPage extends StatefulWidget {
  @override
  State<CounterPage> createState() => _CounterPageState();
}

class _CounterPageState extends State<CounterPage> with ViewModelStateMixin {
  @override
  Widget build(BuildContext context) {
    // Watch the provider. Widget rebuilds when ViewModel updates.
    final vm = vef.watch(counterProvider);

    return Scaffold(
      body: Center(
        child: Text('${vm.count}'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: vm.increment,
        child: Icon(Icons.add),
      ),
    );
  }
}
```

## Features

### 1. Accessing Data (`vef`)

The `vef` object (ViewModel Element Factory) is your gateway to accessing ViewModels.

| Method | Usage |
| :--- | :--- |
| `vef.watch(provider)` | **Access + Listen**. Returns the instance and subscribes to updates (rebuilding the widget). Safe to use in `build()` or `initState()`. |
| `vef.read(provider)` | **Access only**. Returns the instance without subscribing. Does NOT trigger rebuilds. Use this in callbacks (like `onPressed`). |
| `vef.listen(provider)` | **Listen only**. Subscribe to changes to run side-effects (like showing a dialog) without rebuilding. Auto-disposed. |

### 2. Immutable State (`StateViewModel`)

For complex state, it's better to use immutable objects. `StateViewModel` is designed for this.

```dart
// 1. The State Class
class UserState {
  final String name;
  final bool isLoading;
  UserState({this.name = '', this.isLoading = false});
}

// 2. The ViewModel
class UserViewModel extends StateViewModel<UserState> {
  UserViewModel() : super(state: UserState());

  void loadUser() async {
    setState(state.copyWith(isLoading: true)); // Update state
    // ... fetch api ...
    setState(state.copyWith(isLoading: false, name: 'Alice'));
  }
}
```

#### Listening to Changes

You can listen to specific state changes to trigger side effects (like showing a specific dialog or navigation), without rebuilding the widget.

```dart
// Listen to specific property
vef.listenStateSelect(
  userProvider,
  selector: (state) => state.isLoading,
  onChanged: (prev, isLoading) {
    if (isLoading) {
      showLoadingDialog();
    } else {
      dismissLoadingDialog();
    }
  },
);

// Listen to full state
vef.listenState(userProvider, onChanged: (prev, state) {
  print('State changed from $prev to $state');
});
```

### 3. Dependency Injection (Arguments)

Often your ViewModel needs external data (like an ID or a Repository). Passing arguments is built-in.

```dart
// Define provider expecting an argument (int id)
final userProvider = ViewModelProvider.arg<UserViewModel, int>(
  builder: (int id) => UserViewModel(id),
);

// Usage in Widget
final vm = vef.watch(userProvider(123)); // Pass the argument here
```

### 4. Instance Sharing (Keys)

**Default Behavior: Isolation**
When you call `vef.watch(provider)`, you get a **new, private instance** of the ViewModel for that widget. If you use the same provider in another widget, it gets a *different* instance.

**Sharing Behavior: Keys**
To share a ViewModel instance between widgets (e.g., a "Product Detail" and its "Header"), you must explicitly provide a `key`.

**Scenario**: You have a `ProductPage` and need to share the `ProductViewModel` with a child widget `ProductHeader`.

```dart
// 1. Define provider with a key derived from an argument
final productProvider = ViewModelProvider.arg<ProductViewModel, String>(
  builder: (id) => ProductViewModel(id),
  key: (id) => 'product_$id', // Key based on ID
);

// 2. Parent Widget (Page)
class ProductPage extends StatefulWidget {
  final String productId;
  // ...
  build(context) {
    // Creates or finds instance with key 'product_123'
    final vm = vef.watch(productProvider(productId));
    // ...
  }
}

// 3. Child Widget (Header)
class ProductHeader extends StatefulWidget {
  final String productId;
  // ...
  build(context) {
    // Returns the SAME instance as the parent because the key is the same
    final vm = vef.watch(productProvider(productId)); 
    return Text(vm.title);
  }
}
```

### 5. Automatic Lifecycle

`view_model` uses strict reference counting to manage memory.

1.  **Create**: The first time a widget accesses a provider via `watch`, `read`, or `listen`, the ViewModel is created (if not already cached) and the reference count increments.
2.  **Alive**: As long as the widget is mounted, it holds a reference to the ViewModel.
    *   `watch(provider)`: Holds a reference AND listens for updates.
    *   `read(provider)`: Holds a reference (without listening for updates).
    *   `listen(provider)`: Internally calls `read`, so it **ALSO** holds a reference.
3.  **Dispose**: When the widget is disposed, its reference is removed. When the total reference count drops to 0, the ViewModel is automatically disposed (`dispose()` is called).

> **Exception (Keep Alive)**: If you set `aliveForever: true` in your provider, the ViewModel will **NEVER** be automatically disposed, even if the reference count hits 0. It behaves like a global singleton.

### 6. Code Generation (Recommended)

Writing `ViewModelProvider` definitions manually is boring. Use `@genProvider` to automate it.

```dart
@genProvider
class MyViewModel extends ViewModel {}
```

Run `dart run build_runner build` and it generates the provider for you.
See [view_model_generator](../view_model_generator/README.md) for details.

## Testing

You can mock any ViewModel for testing using `setProxy`.

```dart
testWidgets('MyTest', (tester) async {
  final mockVM = MockCounterViewModel();
  
  // Replace the real implementation with the mock
  counterProvider.setProxy(
    ViewModelProvider(builder: () => mockVM)
  );

  await tester.pumpWidget(MyApp());
  // ...
});
```

## Global Configuration

You can configure global behavior in your `main()` function.

```dart
void main() {
  ViewModel.initialize(
    config: ViewModelConfig(
      isLoggingEnabled: true, // Print logs to console
    ),
    // Add global observers for navigation/lifecycle events
    // lifecycles: [], 
  );
  runApp(MyApp());
}
```



## License

MIT License - see [LICENSE](./LICENSE) file.
