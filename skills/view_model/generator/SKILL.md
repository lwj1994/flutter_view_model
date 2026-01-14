
---
name: View Model Generator Usage
description: Guide on how to use the view_model_generator package to automate provider creation.
---

# View Model Generator Usage

The `view_model_generator` package automates the boilerplate of creating `ViewModelProvider`s.

## Installation

Add to your `pubspec.yaml`:

```yaml
dev_dependencies:
  view_model_generator: ^latest_version
  build_runner: ^latest_version
```

## 1. Basic Usage

1.  Add `part` directive using the `.vm.dart` extension.
2.  Annotate your class with `@genProvider`.
3.  Run build runner: `dart run build_runner build` (or `watch`).

```dart
import 'package:view_model/view_model.dart';
// 1. Add part directive
part 'my_view_model.vm.dart';

// 2. Add annotation
@genProvider
class MyViewModel extends ViewModel {
  MyViewModel();
}
```

This generates a top-level `myProvider` (camelCase name).

## 2. Dependency Injection (Arguments)

The generator automatically detects constructor arguments (up to 4) and creates a provider that accepts them.

```dart
@genProvider
class UserViewModel extends ViewModel {
  final int userId;
  final Repository repo;
  
  // Generator detects these args
  UserViewModel(this.userId, this.repo);
}
```

**Usage:**

```dart
// The generated provider is now a function
final vm = vef.watch(userProvider(123, repository));
```

## 3. Singleton Mode (Keep Alive)

To keep a ViewModel alive forever (e.g., Auth, Global Config), use `aliveForever: true`.

```dart
@GenProvider(aliveForever: true, key: "AuthGlobal")
class AuthViewModel extends ViewModel {}
```

## 4. Custom Keys and Expressions

You can define static keys or use `Expression` to reference arguments for dynamic keys.

```dart
// Static string key
@GenProvider(key: 'special_vm')
class MyViewModel extends ViewModel {}

// Dynamic key using argument variable name
@GenProvider(key: Expression('serverId'))
class ServerViewModel extends ViewModel {
  final String serverId;
  ServerViewModel(this.serverId);
}
```

## 5. Custom Factory Logic

If you need custom creation logic (e.g., named constructors, default values), define a factory named `provider`. The generator will use this instead of the default constructor.

```dart
@genProvider
class SettingsViewModel extends ViewModel {
  final bool isDark;
  
  // Private constructor
  SettingsViewModel._({this.isDark = false});

  // Generator uses this factory
  factory SettingsViewModel.provider({required bool isDark}) {
    // Custom logic here
    return SettingsViewModel._(isDark: isDark);
  }
}
```

## Summary

| Feature | Code |
| :--- | :--- |
| **Basic Provider** | `@genProvider` |
| **With Arguments** | `@genProvider` + Constructor with args |
| **Singleton** | `@GenProvider(aliveForever: true)` |
| **Custom Key** | `@GenProvider(key: ...)` |
| **Dynamic Key** | `@GenProvider(key: Expression('argName'))` |
| **Custom Logic** | Define `factory ClassName.provider(...)` |
