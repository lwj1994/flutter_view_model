<p align="center">
  <img src="https://lwjlol-images.oss-cn-beijing.aliyuncs.com/logo.png" alt="ViewModel Logo" height="96" />
</p>

# ✨ view_model: State Management Made Effortless

> **"Everything is ViewModel"** — The missing piece in Flutter architecture. Stop fighting with BuildContext and start building with pure logic.

| Package | Version |
| :--- | :--- |
| **view_model** | [![Pub Version](https://img.shields.io/pub/v/view_model)](https://img.shields.io/pub/v/view_model) |
| **view_model_annotation** | [![Pub Version](https://img.shields.io/pub/v/view_model_annotation)](https://img.shields.io/pub/v/view_model_annotation) |
| **view_model_generator** | [![Pub Version](https://img.shields.io/pub/v/view_model_generator)](https://img.shields.io/pub/v/view_model_generator) |

[![Codecov](https://img.shields.io/codecov/c/github/lwj1994/flutter_view_model/main)](https://app.codecov.io/gh/lwj1994/flutter_view_model/tree/main)

[ChangeLog](https://github.com/lwj1994/flutter_view_model/blob/main/packages/view_model/CHANGELOG.md) | [中文文档](https://github.com/lwj1994/flutter_view_model/blob/main/README_ZH.md)

---

## 🌟 Why you'll love `view_model`

Most state management solutions force you into a corner. You either end up with "Context Hell" or messy global singletons. **view_model** gives you the best of both worlds with zero friction.

*   **🚀 Access Anywhere, Anytime**: Get your ViewModels from widgets, repositories, or services—no `BuildContext` required.
*   **🧼 Clean Architecture by Default**: Repositories, Services, and Helpers? They can all naturally be ViewModels.
*   **⚡ Zero Boilerplate**: Write your logic, add an annotation, and let the generator handle the boring stuff.
*   **🧩 Smart Lifecycle**: ViewModels are created when needed and disposed of automatically when no one is watching.
*   **🤝 Effortless Sharing**: Need a singleton? Use a `key`. Need isolation? Just don't. It's that simple.

---

## 📦 Installation

Add these to your `pubspec.yaml`:

```yaml
dependencies:
  view_model: ^latest_version

dev_dependencies:
  build_runner: ^latest_version
  view_model_generator: ^latest_version # Highly recommended!
```

---

## 🏎️ Quick Start (3 Simple Steps)

### 1. Define your Logic
Extend `ViewModel` and use `update()` to tell the UI when it's time to shine.

```dart
class CounterViewModel extends ViewModel {
  int count = 0;

  void increment() {
    update(() => count++);
  }
}
```

### 2. Register with a Provider
*(Pro-tip: Skip this by using `view_model_generator`!)*

```dart
final counterProvider = ViewModelProvider<CounterViewModel>(
  builder: () => CounterViewModel(),
);
```

### 3. Use it in your Widget
Mix in `ViewModelStateMixin` and start watching.

```dart
class CounterPage extends StatefulWidget {
  @override
  State<CounterPage> createState() => _CounterPageState();
}

class _CounterPageState extends State<CounterPage> with ViewModelStateMixin {
  @override
  Widget build(BuildContext context) {
    // vef.watch makes the widget reactive—it rebuilds when count changes!
    final vm = vef.watch(counterProvider);

    return Scaffold(
      body: Center(child: Text('${vm.count}')),
      floatingActionButton: FloatingActionButton(
        onPressed: vm.increment,
        child: Icon(Icons.add),
      ),
    );
  }
}
```

---

## 🛠️ Core Magic

### 1. Universal Access with `Vef`

`Vef` (ViewModel Execution Framework) is your secret weapon. It’s what allows you to access logic **everywhere** without carrying a `BuildContext` around.

*   **Within Widgets**: Use `ViewModelStateMixin` to gain `vef` powers.
*   **Within ViewModels**: They have `vef` built-in! A `CartViewModel` can easily read from a `UserViewModel`.
*   **Within Any Class**: Repositories, Services, even test helpers can "be" ViewModels and coordinate with each other.

#### 🏁 Quick Reference: Vef Methods

| Method | The Vibe | Best For... |
| :--- | :--- | :--- |
| `vef.watch(provider)` | **Reactive** | Inside `build()` – rebuilds the UI on change. |
| `vef.read(provider)` | **Direct** | Callbacks like `onPressed` or inside other ViewModels. |
| `vef.listen(provider)` | **Impactful** | Side effects like navigation or showing snackbars. |
| `vef.watchCached(key:)` | **Targeted** | Accessing a specific shared instance by its unique key. |

---

### 2. Modern Immutability (`StateViewModel`)

For the "Pro" developers who love clean, immutable states. Pair this with [Freezed](https://pub.dev/packages/freezed) for ultimate power. 🔒

```dart
class UserViewModel extends StateViewModel<UserState> {
  UserViewModel() : super(state: UserState());

  void loadUser() async {
    setState(state.copyWith(isLoading: true));
    // ... magic happens ...
    setState(state.copyWith(isLoading: false, name: 'Alice'));
  }
}
```

#### 💡 Pro-Tip: Legacy APIs are still pure magic! ✨

If you’re a long-time user or simply prefer the explicit, ceremony-filled syntax of `watchViewModel` and `readViewModel`, don't worry—we've got you covered!

The classic methods are **fully supported** and mapped directly to the high-performance `vef` engine under the hood. You get all the new architectural wins while keeping your favorite coding style:

| Classic Method (Legacy) | `vef` Equivalent (Modern) | Why use it? |
| :--- | :--- | :--- |
| `watchViewModel` | `vef.watch` | 👁️ Get + Auto-track changes |
| `readViewModel` | `vef.read` | ⚡ Zero-overhead retrieval |
| `watchCachedViewModel` | `vef.watchCached` | 📦 High-precision cache access |
| `listenViewModel` | `vef.listen` | 👂 React to changes without rebuilds |
| `listenViewModelState` | `vef.listenState` | 📊 Deep state-stream tracing |
| `listenViewModelStateSelect` | `vef.listenStateSelect` | 🎯 Pinpoint property tracking |

The bottom line: **Same features, better performance. Your code, your rules.** ✨

---

### 3. Dependency Injection (Arguments)

ViewModels often need data up-front—like an ID or a Repository. We made passing arguments a breeze. 💨

#### 💡 Real Talk: The "Fake DI" in Flutter 🧐

Let's be honest: True Dependency Injection (like Dagger in Android or Spring in Java) requires reflection or extremely powerful meta-programming. Since Flutter disables reflection and `build_runner` is limited, most "DI" libraries in the ecosystem (like `injectable` or `get_it`) are technically **Service Locators** in disguise.

They pretend to be DI, but they're just finding objects in a global map.

In `view_model`, we chose to **embrace reality** instead of chasing "fake DI" magic. We provide a clean, explicit argument system that gives you the control you need without the hidden complexity. It’s predictable, easy to debug, and works natively with Flutter’s architecture:

```dart
final userProvider = ViewModelProvider.arg<UserViewModel, int>(
  builder: (int id) => UserViewModel(id),
);

// Usage:
final vm = vef.watch(userProvider(42)); 
```

---

### 4. Instance Sharing (Keys)

*   **Isolation (Default)**: Every widget gets its own private ViewModel instance.
*   **Sharing (Keys)**: Need multiple widgets to talk to the *same* instance? Just give them a `key`.

```dart
final productProvider = ViewModelProvider.arg<ProductViewModel, String>(
  builder: (id) => ProductViewModel(id),
  key: (id) => 'prod_$id', // Shared based on ID
);
```

---

### 5. Automatic Lifecycle ♻️

We manage the memory so you don't have to. 
1.  **Creation**: Triggers on first `watch`, `read`, or `listen`.
2.  **Persistence**: viewModel stays alive as long as someone is watching.
3.  **Clean-up**: Once the last widget unmounts, the ViewModel is automatically disposed of.

*Need it to live forever?* Just set `aliveForever: true`. It’s perfect for Auth sessions or App settings.

---

## 🏗️ Architecture Patterns: Clean Code Edition

In a real-world app, every layer of your architecture can benefit from `view_model`. Using ViewModels as "Repositories" allows them to coordinate with "Auth" or "Storage" services seamlessly without passing around `BuildContext`.

Check out our **[Best Practices Guide](./AI_GUIDE.md)** for more in-depth patterns.

---

## 🧪 Bulletproof Testing

Testing is a first-class citizen here. Mocking ViewModels is straightforward, and you can verify your logic without ever launching a simulator.

```dart
testWidgets('Displays the right user data', (tester) async {
  final mockVM = MockUserViewModel();
  // Override the real VM with your mock
  userProvider.setProxy(ViewModelProvider(builder: () => mockVM));

  await tester.pumpWidget(MyApp());
  expect(find.text('Alice'), findsOneWidget);
});
```

---

## 🛠️ Global Configuration

Set up your rules in `main()`:

```dart
void main() {
  ViewModel.initialize(
    config: ViewModelConfig(
      isLoggingEnabled: true,
      onListenerError: (error, stack, context) {
         // Report to Crashlytics
      },
    ),
  );
  runApp(MyApp());
}
```

---

## 📜 License

Distributed under the MIT License. See `LICENSE` for more information.

---
*Built with ❤️ for the Flutter community.*
