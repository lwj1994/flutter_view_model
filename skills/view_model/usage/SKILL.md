
---
name: View Model Usage
description: Guide on how to use the view_model package correctly based on its README.
---

# View Model Usage Guide

## Step 1️⃣: Write Your Business Logic

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

## Step 2️⃣: Register a Provider

```dart
final counterProvider = ViewModelProvider<CounterViewModel>(
  builder: () => CounterViewModel(),
);
```

**Pro tip**: Skip this step entirely by using `view_model_generator`—just add an annotation and it's auto-generated! 🎉

```dart
// Part of file: counter_view_model.vm.dart
@genProvider
class CounterViewModel with ViewModel { ... }
```

---

## Step 3️⃣: Use in Your Widget

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

## Universal Access with Vef

`Vef` = ViewModel Execution Framework. It's a mixin you can add to **any class**, giving it the power to access ViewModels anywhere!

### In Any Class (Custom Ref)

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

## Quick Reference: Vef Methods

| Method | Behavior | Best For |
| :--- | :--- | :--- |
| `vef.watch(provider)` | **Reactive** | Inside `build()`—rebuilds on change |
| `vef.read(provider)` | **Direct access** | Callbacks, event handlers, or other ViewModels |
| `vef.listen(provider)` | **Side effects** | Navigation, snackbars, etc. |
| `vef.watchCached(key:)` | **Targeted** | Access specific shared instance by key |
| `vef.readCached(key:)` | **Targeted** | Read specific shared instance without listening |
| `vef.listenState(provider)` | **State Listener** | Listen to state changes (previous, current) |
| `vef.listenStateSelect(provider)` | **Selector** | Listen to specific state property changes |

## Immutable State (StateViewModel)

For developers who love clean, immutable state! Pairs beautifully with Freezed ✨

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

## Dependency Injection (Arguments)

```dart
final userProvider = ViewModelProvider.arg<UserViewModel, int>(
  builder: (int id) => UserViewModel(id),
);

// Usage:
final vm = vef.watch(userProvider(42));
```

## Instance Sharing (Keys)

- **Isolated by default**: Each widget gets its own ViewModel instance
- **Shared instances**: Add a `key`, and widgets with the same key share the same instance

```dart
final productProvider = ViewModelProvider.arg<ProductViewModel, String>(
  builder: (id) => ProductViewModel(id),
  key: (id) => 'prod_$id',  // Same ID = shared instance
);
```

## Automatic Lifecycle ♻️

1. **Creation**: Auto-created on first `watch` or `read`
2. **Alive**: Stays alive as long as any widget is using it
3. **Disposal**: Auto-cleaned when the last user unmounts

**Need a global singleton?** Add `aliveForever: true`.

```dart
final authProvider = ViewModelProvider(
  builder: () => AuthViewModel(),
  aliveForever: true,  // Never disposed
);
```
