---
name: Architecture Recommendation
description: Guidelines for structuring applications using the view_model package, promoting a simplified, mixin-based architecture.
---

---
name: Architecture Recommendation
description: Guidelines for structuring applications using the view_model package, promoting a simplified, mixin-based architecture.
---

# Architecture Recommendation

The `view_model` package promotes a simplified architecture where **everything can be a ViewModel**. By leveraging the `ViewModel` and `Vef` mixins, you can eliminate complex layering often found in other architectures.

## Core Principles

1.  **Universal Component**: Widgets, Repositories, Services, and Managers can all be `ViewModel`s.
2.  **No Context Hell**: Access state and logic anywhere without passing `BuildContext`.
3.  **Composition over Inheritance**: Use mixins (`with ViewModel`, `with Vef`) to add capabilities.

## 1. Universal Component (`with ViewModel`)

Transform any class into a capable component by mixing in `ViewModel`. This gives it access to `vef` for dependency injection and lifecycle management.

```dart
class UserRepository with ViewModel {
  Future<User> fetchUser() async {
    // Access other ViewModels seamlessly via 'vef'
    final token = vef.read(authProvider).token;
    return api.get(token);
  }
}
```

## 2. Dependency Injection (VM ↔ VM)

ViewModels interpret dependencies by simply reading other providers.

```dart
class CartViewModel with ViewModel {
  void checkout() {
    // 1. Get UserViewModel instance
    final userVM = vef.read(userProvider);
    
    // 2. Use it directly
    if (userVM.isLoggedIn) {
      processOrder();
    }
  }
}
```

## 3. Reactive Logic (Internal Listening)

ViewModels can listen to other ViewModels (`listenState`) and react to changes automatically, keeping business logic encapsulated.

```dart
class ChatViewModel with ViewModel {
  ChatViewModel() {
    // Automatically react when AuthProvider's state changes
    listenState(authProvider, (previous, next) {
      if (next.isLoggedOut) {
        clearMessages();
      }
    });
  }
}
```

## 4. Initialization & Tasks (`with Vef`)

For logic that doesn't need to hold state or be a ViewModel (like startup tasks), use `with Vef` to gain access to the provider system.

```dart
class AppInitializer with Vef {
  Future<void> init() async {
    // Read and initialize ViewModels sequentially or parallelly
    await vef.read(configProvider).fetch();
    await vef.read(authProvider).check();
  }
}

// Usage in main
void main() {
  AppInitializer().init();
  runApp(MyApp());
}
```

## 5. Singletons & Global State

For services that must remain alive throughout the app lifecycle (Auth, Settings), use `aliveForever: true`.

```dart
final authProvider = ViewModelProvider(
  builder: () => AuthViewModel(),
  key: (_) => 'auth_global', // Optional: simpler debugging
  aliveForever: true,        // Prevents auto-disposal
);
```

## Summary

| Component | Mixin | Usage |
| :--- | :--- | :--- |
| **Widget** | `ViewModelStateMixin` | UI rendering, binding to ViewModels |
| **Business Logic** | `ViewModel` | State management, simple logic |
| **Service/Repo** | `ViewModel` | Data fetching, complex logic, dependencies |
| **TaskScript** | `Vef` | Scripts, initialization, one-off tasks |
