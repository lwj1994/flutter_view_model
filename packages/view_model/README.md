<p align="center">
  <img src="https://lwjlol-images.oss-cn-beijing.aliyuncs.com/logo.png" alt="ViewModel Logo" height="96" />
</p>

# ✨ view_model: Lightweight Flutter State Management

> **Ultra-lightweight (just `with`) | Zero intrusion | Say goodbye to BuildContext hell**
>
> Only ~6K lines of code, yet transforms your architecture completely 🚀

| Package | Version |
| :--- | :--- |
| **view_model** | [![Pub Version](https://img.shields.io/pub/v/view_model)](https://img.shields.io/pub/v/view_model) |
| **view_model_annotation** | [![Pub Version](https://img.shields.io/pub/v/view_model_annotation)](https://img.shields.io/pub/v/view_model_annotation) |
| **view_model_generator** | [![Pub Version](https://img.shields.io/pub/v/view_model_generator)](https://img.shields.io/pub/v/view_model_generator) |

[![Codecov](https://img.shields.io/codecov/c/github/lwj1994/flutter_view_model/main)](https://app.codecov.io/gh/lwj1994/flutter_view_model/tree/main)

[ChangeLog](https://github.com/lwj1994/flutter_view_model/blob/main/packages/view_model/CHANGELOG.md) | [中文文档](README_ZH.md) | [Architecture Guide](ARCHITECTURE_GUIDE.md)

---

## 💡 Why view_model?


### ✨ Three Core Strengths

#### 🪶 **Ultra-Lightweight = Zero Overhead**
- **Minimal footprint**: Only ~6K lines of code, 3 dependencies (flutter + meta + stack_trace)
- **Zero setup**: No root widget wrapping, no mandatory initialization
- **On-demand creation**: ViewModels are created lazily and disposed automatically

#### 🎯 **Minimal Intrusion = Maximum Compatibility**
- **Just `with`**: Add `with ViewModelStateMixin` to your State—that's it
- **Drop-in ready**: Works with any existing Flutter code, integrate anytime
- **Pure Dart mixins**: Leverages Dart 3 mixin capabilities, zero inheritance pollution

#### 🌈 **Complete Flexibility**
- **Access anywhere**: Use ViewModels in Widgets, Repositories, Services—no `BuildContext` needed
- **Automatic memory management**: Reference counting + auto-disposal means no memory leaks
- **Share or isolate**: Need a singleton? Add a `key`. Need isolation? Don't. It's that simple.

---

## 📦 Installation

```yaml
dependencies:
  view_model: ^latest_version

dev_dependencies:
  build_runner: ^latest_version
  view_model_generator: ^latest_version  # Highly recommended for less boilerplate!
```

---

## 🚀 Get Started in 3 Steps

### Step 1️⃣: Write Your Business Logic

**Just use `with ViewModel`** (yes, it's that simple):

```dart
class CounterViewModel with ViewModel {
  int count = 0;

  void increment() {
    update(() => count++);  // Automatically notifies UI
  }
}
```

**Why `with` instead of `extends`?**
Dart mixins enable composition over inheritance—more flexible and keeps your class hierarchy clean!

---

### Step 2️⃣: Register a Provider

```dart
final counterProvider = ViewModelProvider<CounterViewModel>(
  builder: () => CounterViewModel(),
);
```

**Pro tip**: Skip this step entirely by using `view_model_generator`—just add an annotation and it's auto-generated! 🎉

---

### Step 3️⃣: Use in Your Widget

**Add one mixin, unlock superpowers**:

```dart
class CounterPage extends StatefulWidget {
  @override
  State<CounterPage> createState() => _CounterPageState();
}

class _CounterPageState extends State<CounterPage>
    with ViewModelStateMixin {  // 👈 Just this one line!

  @override
  Widget build(BuildContext context) {
    final vm = vef.watch(counterProvider);  // Automatically listens

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

**Intrusion comparison**:

| Solution | Changes Required | Root Wrapping | BuildContext Dependency |
|----------|------------------|---------------|------------------------|
| **view_model** | ✅ Just add mixin | ❌ No | ❌ No |
| Provider | ⚠️ InheritedWidget | ✅ Yes | ✅ Yes |
| Riverpod | ⚠️ ConsumerWidget | ✅ Yes | ❌ No |
| GetX | ⚠️ Often global state | ❌ No | ❌ No |

---

## 🛠️ Core Features

### 1️⃣ Universal Access with Vef (Custom Ref)

**What is `vef`?**
`Vef` = ViewModel Execution Framework. It's a mixin you can add to **any class**, giving it the power to access ViewModels anywhere!

#### 📱 In Widgets (Built-in)

```dart
class _MyPageState extends State<MyPage> with ViewModelStateMixin {
  @override
  Widget build(BuildContext context) {
    final vm = vef.watch(myProvider);  // Auto-reactive
    return Text(vm.data);
  }
}
```

#### 🧠 In ViewModels (Built-in)

ViewModels can coordinate with each other:

```dart
class CartViewModel with ViewModel {
  void checkout() {
    final userVM = vef.read(userProvider);  // Direct access to other VMs
    processOrder(userVM.user);
  }
}
```

#### 🏗️ In Any Class (Custom Ref)

Need a pure logic manager? Just `with Vef`:

```dart
class StartupTaskRunner with Vef {
  Future<void> run() async {
    final authVM = vef.read(authProvider);
    await authVM.checkAuth();

    final configVM = vef.read(configProvider);
    await configVM.fetchRemoteConfig();
  }

  @override
  void dispose() {
    super.dispose();  // Auto-cleans all dependencies
  }
}
```

#### 🎯 Quick Reference: Vef Methods

| Method | Behavior | Best For |
| :--- | :--- | :--- |
| `vef.watch(provider)` | **Reactive** | Inside `build()`—rebuilds on change |
| `vef.read(provider)` | **Direct access** | Callbacks, event handlers, or other ViewModels |
| `vef.listen(provider)` | **Side effects** | Navigation, snackbars, etc. |
| `vef.watchCached(key:)` | **Targeted** | Access specific shared instance by key |

---

### 2️⃣ Immutable State (StateViewModel)

For developers who love clean, immutable state! Pairs beautifully with [Freezed](https://pub.dev/packages/freezed) ✨

```dart
class UserViewModel extends StateViewModel<UserState> {
  UserViewModel() : super(state: UserState());

  void loadUser() async {
    setState(state.copyWith(isLoading: true));
    // ... fetch data ...
    setState(state.copyWith(isLoading: false, name: 'Alice'));
  }
}
```

**Legacy API support**: Prefer the classic `watchViewModel` syntax? Go ahead! It's fully supported and powered by the high-performance `vef` engine under the hood:

| Legacy Method | Modern Equivalent | Description |
| :--- | :--- | :--- |
| `watchViewModel` | `vef.watch` | Watch + auto-rebuild |
| `readViewModel` | `vef.read` | Direct read, zero overhead |
| `listenViewModel` | `vef.listen` | Listen without rebuild |

---

### 3️⃣ Dependency Injection (Arguments)

**Real talk**: Many Flutter "DI" libraries are actually **Service Locators** in disguise. True DI requires reflection or powerful meta-programming, but Flutter disables reflection.

We chose to **embrace reality**—use a clean, explicit argument system:

```dart
final userProvider = ViewModelProvider.arg<UserViewModel, int>(
  builder: (int id) => UserViewModel(id),
);

// Usage:
final vm = vef.watch(userProvider(42));
```

Simple, direct, debuggable. No magic tricks.

---

### 4️⃣ Instance Sharing (Keys)

- **Isolated by default**: Each widget gets its own ViewModel instance
- **Shared instances**: Add a `key`, and widgets with the same key share the same instance

```dart
final productProvider = ViewModelProvider.arg<ProductViewModel, String>(
  builder: (id) => ProductViewModel(id),
  key: (id) => 'prod_$id',  // Same ID = shared instance
);
```

---

### 5️⃣ Automatic Lifecycle ♻️

**Set it and forget it—memory management handled automatically:**

1. **Creation**: Auto-created on first `watch` or `read`
2. **Alive**: Stays alive as long as any widget is using it
3. **Disposal**: Auto-cleaned when the last user unmounts

**Need a global singleton?** Add `aliveForever: true`, perfect for Auth, App Config, etc:

```dart
final authProvider = ViewModelProvider(
  builder: () => AuthViewModel(),
  aliveForever: true,  // Never disposed
);
```

---

## 🏗️ Architecture Patterns

In real-world apps, Repositories and Services can use `with ViewModel` to coordinate with other ViewModels—no `BuildContext` passing needed:

```dart
class UserRepository with ViewModel {
  Future<User> fetchUser() async {
    final token = vef.read(authProvider).token;  // Direct access
    return api.getUser(token);
  }
}
```

For detailed patterns, check out our **[Architecture Guide](ARCHITECTURE_GUIDE.md)**

---

## 🧪 Testing Made Easy

Mocking is straightforward—no simulator required:

```dart
testWidgets('Displays correct user data', (tester) async {
  final mockVM = MockUserViewModel();
  userProvider.setProxy(ViewModelProvider(builder: () => mockVM));

  await tester.pumpWidget(MyApp());
  expect(find.text('Alice'), findsOneWidget);
});
```

---

## ⚙️ Global Configuration

Configure in `main()`:

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

## 📊 The Numbers Don't Lie

| Metric | Value |
|--------|-------|
| Core codebase | ~6K lines (with comments) |
| Required dependencies | 3 (flutter, meta, stack_trace) |
| Mixins needed | 1 (`ViewModelStateMixin`) |
| Root widget wrapping | ❌ None |
| Mandatory initialization | ❌ Optional |
| Performance overhead | Minimal (reference counting + Zone) |

---

## 📜 License

MIT License—use it freely! 💖

---

## 🎉 Bottom Line

Tired of:
- ❌ Passing `BuildContext` everywhere
- ❌ Complex global state management
- ❌ Memory leaks
- ❌ Invasive code changes

Try **view_model**! **Lightweight, clean, elegant**—it'll transform how you build Flutter apps ✨

**Remember**: Just `with`, and everything becomes simple!

---

*Built with ❤️ for the Flutter community.*
