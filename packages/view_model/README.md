<p align="center">
  <img src="https://lwjlol-images.oss-cn-beijing.aliyuncs.com/logo.png" alt="ViewModel Logo" height="96" />
</p>

# ✨ view_model: Flutter-Native State Management

> **Designed for Flutter's OOP & Widget style** - Low intrusion | VM-to-VM access | Any class can be ViewModel | Fine-grained updates
>
> Built for Flutter, not ported from web frameworks 🚀

| Package | Version |
| :--- | :--- |
| **view_model** | [![Pub Version](https://img.shields.io/pub/v/view_model)](https://img.shields.io/pub/v/view_model) |
| **view_model_annotation** | [![Pub Version](https://img.shields.io/pub/v/view_model_annotation)](https://img.shields.io/pub/v/view_model_annotation) |
| **view_model_generator** | [![Pub Version](https://img.shields.io/pub/v/view_model_generator)](https://img.shields.io/pub/v/view_model_generator) |

[![Codecov](https://img.shields.io/codecov/c/github/lwj1994/flutter_view_model/main)](https://app.codecov.io/gh/lwj1994/flutter_view_model/tree/main)

[ChangeLog](https://github.com/lwj1994/flutter_view_model/blob/main/packages/view_model/CHANGELOG.md) | [中文文档](README_ZH.md) | [Architecture Guide](ARCHITECTURE_GUIDE.md)

---

## Agent Skills
For AI Agent usage, see **[Agent Skills](https://github.com/lwj1994/flutter_view_model/blob/main/skills/view_model/SKILL.md)**.


## 💡 Why "reinventing wheel"?
Our team is a hybrid one consisting of Android, iOS, and Flutter developers. We are accustomed to using the MVVM pattern. We used Riverpod in the past, but we didn't quite like it. We are in greater need of a library that adheres more closely to the ViewModel concept.

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

> 💡 **Fun fact**: `ViewModelStateMixin` is actually powered by `WidgetVef` under the hood—a Flutter-optimized variant of `Vef`. This ensures a consistent API whether you're in Widgets, ViewModels, or pure Dart classes!

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
    super.dispose(); 
  }
}

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
| `vef.readCached(key:)` | **Targeted** | Read specific shared instance without listening |
| `vef.listenState(provider)` | **State Listener** | Listen to state changes (previous, current) |
| `vef.listenStateSelect(provider)` | **Selector** | Listen to specific state property changes |

**Legacy API support**: Prefer the classic `watchViewModel` syntax? Go ahead! It's fully supported and powered by the high-performance `vef` engine under the hood:

| Legacy Method | Modern Equivalent | Description |
| :--- | :--- | :--- |
| `watchViewModel` | `vef.watch` | Watch + auto-rebuild |
| `readViewModel` | `vef.read` | Direct read, zero overhead |
| `listenViewModel` | `vef.listen` | Listen without rebuild |
| `watchCachedViewModel` | `vef.watchCached` | Watch cached instance |
| `readCachedViewModel` | `vef.readCached` | Read cached instance |
| `listenViewModelState` | `vef.listenState` | Listen to state changes |
| `listenViewModelStateSelect` | `vef.listenStateSelect` | Listen to selected state changes |

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

---

### 3️⃣ Fine-Grained Reactivity

**Performance optimization starts here!** Why rebuild your whole widget when only one field changed?

#### 🎯 Option 1: StateViewModelValueWatcher

**Perfect for partial updates in `StateViewModel`**—only rebuild when specific fields change:

```dart
class UserViewModel extends StateViewModel<UserState> {
  UserViewModel() : super(state: UserState(name: '', age: 0, city: ''));

  void updateName(String name) => 
    setState(state.copyWith(name: name));
  
  void updateAge(int age) => 
    setState(state.copyWith(age: age));
}

// In your widget:
class _PageState extends State<Page> with ViewModelStateMixin {
  @override
  Widget build(context) {
    final vm = vef.read(userProvider);  // 👈 use read(), not watch()
    
    return Column(
      children: [
        // ✅ Only rebuilds when name OR age changes, NOT when city changes
        StateViewModelValueWatcher<UserState>(
          viewModel: vm,
          selectors: [
            (state) => state.name,
            (state) => state.age,
          ],
          builder: (state) {
            return Text('${state.name}, ${state.age} years old');
          },
        ),
        
        // ✅ Independent update area—only rebuilds when city changes
        StateViewModelValueWatcher<UserState>(
          viewModel: vm,
          selectors: [(state) => state.city],
          builder: (state) {
            return Text('Lives in: ${state.city}');
          },
        ),
      ],
    );
  }
}
```

**When to use:**
- ✅ You're using `StateViewModel`
- ✅ Your state object has many fields
- ✅ Different UI parts depend on different fields
- ✅ You want surgical precision in rebuilds

---

#### 🎯 Option 2: ObservableValue + ObserverBuilder

**Standalone reactive values**—perfect for simple, isolated state:

```dart
class _PageState extends State<Page> {
  // Create reactive values (no ViewModel needed!)
  final counter = ObservableValue<int>(0);
  final username = ObservableValue<String>('Guest');

  @override
  Widget build(context) {
    return Column(
      children: [
        // ✅ Only rebuilds when counter changes
        ObserverBuilder<int>(
          observable: counter,
          builder: (count) => Text('Count: $count'),
        ),
        
        // ✅ Only rebuilds when username changes
        ObserverBuilder<String>(
          observable: username,
          builder: (name) => Text('Hello, $name!'),
        ),
        
        ElevatedButton(
          onPressed: () => counter.value++,  // Triggers rebuild
          child: Text('Increment'),
        ),
      ],
    );
  }
}
```

**Share values across widgets** using `shareKey`:

```dart
final sharedCounter = ObservableValue<int>(0, shareKey: 'app_counter');

// Widget A:
ObserverBuilder<int>(
  observable: sharedCounter,
  builder: (count) => Text('A sees: $count'),
)

// Widget B:
ObserverBuilder<int>(
  observable: sharedCounter,
  builder: (count) => Text('B sees: $count'),  // Auto-synced!
)
```

**Multiple values?** Use `ObserverBuilder2` or `ObserverBuilder3`:

```dart
ObserverBuilder2<int, String>(
  observable1: counter,
  observable2: username,
  builder: (count, name) {
    return Text('$name clicked $count times');
  },
)
```

**When to use:**
- ✅ Simple, isolated state (toggles, counters, form fields)
- ✅ No need for a full ViewModel
- ✅ Want minimal boilerplate
- ✅ Need to share individual values across widgets

---

**Performance comparison:**

| Approach | Rebuild Scope | Best For |
|----------|--------------|----------|
| `vef.watch(provider)` | Entire widget | Simple cases, few fields |
| `StateViewModelValueWatcher` | Selected fields only | Complex StateViewModel |
| `ObservableValue` | Per-value granularity | Standalone reactive values |

**Pro tip**: Combine them! Use `vef.watch()` for your main structure, then sprinkle `StateViewModelValueWatcher` or `ObserverBuilder` in the hot-path areas that update frequently. 🚀

---

### 4️⃣ Dependency Injection (Arguments)

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

Configure in `main()` to customize the system behavior:

```dart
void main() {
  ViewModel.initialize(
    config: ViewModelConfig(
      isLoggingEnabled: true, // Enable debug logs
      // Custom equality logic for StateViewModel & selectors
      equals: (prev, curr) => prev == curr, 
      // Handle errors in listeners (e.g., Crashlytics)
      onListenerError: (error, stack, context) {
         FirebaseCrashlytics.instance.recordError(error, stack);
      },
      // Handle errors during resource disposal
      onDisposeError: (error, stack) {
         debugPrint('Disposal error: $error');
      },
    ),
  );
  runApp(MyApp());
}
``` |
| Parameter | Default | Description |
| :--- | :--- | :--- |
| `isLoggingEnabled` | `false` | Enable/disable debug information output. |
| `equals` | `identical` | Custom equality function for state change detection. |
| `onListenerError` | `null` | Callback for errors thrown during listener notification. |
| `onDisposeError` | `null` | Callback for errors thrown during object disposal. |


