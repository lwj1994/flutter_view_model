# AI Assistant Guide for `view_model`

This document is designed to be fed into AI assistants (like Cursor, Trae, Copilot, ChatGPT) to teach them how to correctly use the `view_model` package in Flutter.

---

## 🤖 System Prompt / Context for AI

**Copy and paste the following block into your AI's custom instructions or project rules:**

```markdown
# `view_model` Package Guidelines

You are an expert in the Flutter `view_model` package. Follow these rules when generating code:

## 1. Core Concepts
- **ViewModel**: Extends `ViewModel` or `StateViewModel<T>`. Holds logic and state.
- **ViewModelProvider**: Defines how to create a ViewModel.
- **vef**: The accessor object (available in mixins) used to `watch` or `read` ViewModels.
- **Mixins**: 
  - Use `with ViewModelStatelessMixin` for `StatelessWidget`.
  - Use `with ViewModelStateMixin` for `State<T>`.

## 2. Syntax & Patterns

### Defining a Simple ViewModel
```dart
class CounterVM extends ViewModel {
  int count = 0;
  void increment() => update(() => count++); // update() handles notifyListeners
}
```

### Defining a StateViewModel (Immutable State)
```dart
class UserState {
  final String name;
  final bool loading;
  UserState({this.name = '', this.loading = false});
}

class UserVM extends StateViewModel<UserState> {
  UserVM() : super(UserState());

  Future<void> fetchUser() async {
    setState(state.copyWith(loading: true)); // setState() updates state
    // ... api call ...
    setState(state.copyWith(name: 'Alice', loading: false));
  }
}
```

### Providing
```dart
final counterProvider = ViewModelProvider(
  builder: () => CounterVM(),
  // Optional: key or tag for sharing instances
);
```

### Consuming in Widgets
**DO NOT** use `Consumer` or `Provider.of`.
**ALWAYS** use the `vef` accessor provided by the mixin.

```dart
class CounterPage extends StatelessWidget with ViewModelStatelessMixin {
  @override
  Widget build(BuildContext context) {
    // watch(): Rebuilds widget when VM notifies
    final vm = vef.watch(counterProvider); 
    
    return Scaffold(
      body: Center(child: Text('${vm.count}')),
      floatingActionButton: FloatingActionButton(
        onPressed: vm.increment, // Direct method call
        child: Icon(Icons.add),
      ),
    );
  }
}
```

## 3. Critical Rules
- **Never** pass `BuildContext` to a ViewModel. ViewModels are widget-agnostic.
- **Avoid** `notifyListeners()` manually; use `update(() { ... })` in `ViewModel`.
- **Avoid** setting state manually in `StateViewModel`; use `setState(newState)`.
- **Dependency Injection**: ViewModels can find other ViewModels using `vef.read/watch` if they have access to a `Vef` context, or pass dependencies via constructor.
- **Lifecycle**: Managed via **reference counting**. The instance is created when first bound (e.g., `vef.watch/read`) and `dispose()` is automatically called when the binder count drops to 0 (no bindings remain).

## 4. Common Scenarios

### Navigation
Perform navigation in the UI (Widget) layer based on state changes, OR use a separate `NavigationService` injected into the VM. Do NOT import `material.dart` inside the VM logic file if possible (keep it pure Dart).

### Global State
For global/singleton VMs, just define them and use them. They will be created once and reused if kept alive or if the scope dictates.
```

---

## Tips for Developers

- **Generating Boilerplate**: You can ask AI to "Create a StateViewModel for a Login feature with email and password fields".
- **Refactoring**: Ask AI to "Convert this StatefulWidget to a ViewModel + ViewModelStatelessMixin".
