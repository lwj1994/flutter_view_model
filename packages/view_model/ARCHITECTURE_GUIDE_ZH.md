# 🏗️ 架构指南（极简版）

> **核心哲学**：万物皆可 ViewModel。

在 `view_model` 中，你不需要复杂的架构分层。只需要给任何类（Widget, Repository, Service）加上 `with ViewModel`，它就拥有了完整的超能力。

---

## 1️⃣ 万能组件 (`with ViewModel`)

无论是 **Repository**、**Service** 还是 **Manager**，只要混入 `ViewModel`：

```dart
class UserRepository with ViewModel {
  Future<User> fetchUser() async {
    // 无缝访问其他 ViewModel
    final token = vef.read(authProvider).token;
    return api.get(token);
  }
}
```

---

## 2️⃣ 依赖注入 (VM ↔ VM)

ViewModel 之间可以通过读取 provider 轻松实现依赖注入。

```dart
class CartViewModel with ViewModel {
  void checkout() {
    // 1. 获取 UserViewModel
    final userVM = vef.read(userProvider);
    
    // 2. 使用它
    if (userVM.isLoggedIn) {
      // ...
    }
  }
}
```

---

## 3️⃣ 响应式逻辑 (内部监听)

ViewModel 可以监听其他 VM 的变化并做出**自动响应**。

```dart
class ChatViewModel with ViewModel {
  ChatViewModel() {
    // 监听 AuthViewModel 的状态变化
    listenState(authProvider, (previous, next) {
      if (next.isLoggedOut) {
        clearMessages();
      }
    });
  }
}
```

---

## 4️⃣ 初始化任务 (`with Vef`)

对于启动逻辑或不需要成为 ViewModel 的独立任务，使用 `with Vef`。

```dart
class AppInitializer with Vef {
  Future<void> init() async {
    // 读取并初始化 ViewModels
    await vef.read(configProvider).fetch();
    await vef.read(authProvider).check();
  }
}

// 在 main 中使用
void main() {
  AppInitializer().init();
  runApp(MyApp());
}
```

---

## 5️⃣ 全局单例 (`aliveForever`)

对于 Auth 或 Settings 这种全局实例，可以让它们永生（永不销毁）。

```dart
final authProvider = ViewModelProvider(
  builder: () => AuthViewModel(),
  key: 'auth', // 全局 Key
  aliveForever: true, // 永不销毁
);
```
