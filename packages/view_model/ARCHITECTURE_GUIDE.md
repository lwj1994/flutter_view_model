# 🏗️ Simplified Architecture Guide

> **Core Philosophy**: Everything can be a ViewModel.

In `view_model`, you don't need complex layers. Just add `with ViewModel` to any class (Widget, Repository, Service) to gain full capabilities.

---

## 1️⃣ Universal Component (`with ViewModel`)

Whether it's a **Repository**, **Service**, or **Manager**, just mix in `ViewModel`.

```dart
class UserRepository with ViewModel {
  Future<User> fetchUser() async {
    // Access other ViewModels seamlessly
    final token = read(authSpec).token;
    return api.get(token);
  }
}
```

---

## 2️⃣ Dependency Injection (VM ↔ VM)

ViewModels can easily inject dependencies by reading other providers.

```dart
class CartViewModel with ViewModel {
  void checkout() {
    // 1. Get UserViewModel
    final userVM = read(userSpec);
    
    // 2. Use it
    if (userVM.isLoggedIn) {
      // ...
    }
  }
}
```

---

## 3️⃣ Reactive Logic (Internal Listening)

ViewModels can listen to others and react **automatically**.

```dart
class ChatViewModel with ViewModel {
  ChatViewModel() {
    // Listen to Auth State changes
    // Reacts whenever AuthState changes
    listenState(authSpec, (previous, next) {
      if (next.isLoggedOut) {
        clearMessages();
      }
    });
  }
}
```

---

## 4️⃣ Initialization Tasks (`with ViewModelBinding`)

For startup logic or standalone tasks that don't need to be a ViewModel itself, use `with ViewModelBinding`.

```dart
class AppInitializer with ViewModelBinding {
  Future<void> init() async {
    // Read and initialize ViewModels
    await read(configSpec).fetch();
    await read(authSpec).check();
  }
}

// Usage in main
void main() {
  AppInitializer().init();
  runApp(MyApp());
}
```

---

## 5️⃣ Singletons (`aliveForever`)

For global instances like Auth or Settings, keep them alive forever.

```dart
final authSpec = ViewModelSpec(
  builder: () => AuthViewModel(),
  key: 'auth', // Global key
  aliveForever: true, // Never disposed
);
```
