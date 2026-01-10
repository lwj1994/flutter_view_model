# view_model_generator

Code generator for the `view_model` package.

## The Problem

When using `view_model`, you typically need to define a global `ViewModelProvider` so that your widgets can access the ViewModel. Writing this definition manually for every ViewModel is repetitive and error-prone, usually looking like this:

```dart
// Without generator :(
final myProvider = ViewModelProvider<MyViewModel>(
  builder: () => MyViewModel(),
);
```

## The Solution

**view_model_generator** automates this process. You simply annotate your ViewModel class, and it generates the `ViewModelProvider` for you.

```dart
// With generator :)
@genProvider
class MyViewModel extends ViewModel {}
```

## Installation

Add `view_model_generator` to your `dev_dependencies`:

```yaml
dev_dependencies:
  view_model_generator: ^latest_version
  build_runner: ^latest_version
```

## Features

### 1. Basic Usage

1.  **Annotate**: Add `@genProvider` to your class.
2.  **Run**: Run `dart run build_runner build`.

```dart
import 'package:view_model/view_model.dart';
part 'my_view_model.vm.dart';

@genProvider
class MyViewModel extends ViewModel {
  MyViewModel();
}
```

This generates a file `my_view_model.vm.dart` containing:

```dart
final myProvider = ViewModelProvider<MyViewModel>(
  builder: () => MyViewModel(),
);
```

The generated provider name is always **camelCase** of your class name + `Provider` (e.g., `UserViewModel` -> `userProvider`).

### 2. Handling Arguments (Dependency Injection)

If your ViewModel constructor requires arguments (like a repository or an ID), the generator automatically creates a provider that accepts those arguments.

```dart
@genProvider
class UserViewModel extends ViewModel {
  final int userId;
  final Repository repo;

  // The generator detects these required arguments
  UserViewModel(this.userId, this.repo);
}
```

**Usage in UI:**

```dart
// 1. Pass the arguments to the provider to get the factory
final factory = userProvider(123, repository);

// 2. Watch it
final vm = vef.watch(factory);
```

Or simply:

```dart
final vm = vef.watch(userProvider(123, repository));
```

*Note: The generator supports up to 4 required arguments.*

### 3. Alive Forever (Singleton-like)

If you want a ViewModel to stay in memory even when no widgets are using it (e.g., a global authentication store), set `aliveForever: true`. It is recommended to provide a **fixed key** so you can easily access this singleton instance from anywhere.

```dart
@GenProvider(aliveForever: true, key: "AuthViewModel")
class AuthViewModel extends ViewModel {}
```

### 4. Custom Keys and Tags

You can customize the `key` and `tag` used by the provider. This is useful for identifying specific instances in debug tools or logs.

```dart
@GenProvider(key: 'special_vm', tag: 'v1')
class MyViewModel extends ViewModel {}
```

You can even use expressions:

```dart
@GenProvider(key: Expression('server_id'))
class ServerViewModel extends ViewModel {
  final String serverId;
  ServerViewModel(this.serverId);
}
```

### 5. Advanced: Factory Control

By default, the generator creates the ViewModel using its main constructor, using only the **required** parameters.

If you need more control (e.g., to expose optional parameters or use a named constructor), define a factory named `provider`.

```dart
@genProvider
class SettingsViewModel extends ViewModel {
  final bool isDark;
  
  // 'isDark' is optional here
  SettingsViewModel({this.isDark = false});

  // The generator will use this factory instead of the constructor.
  // This allows you to expose 'isDark' as a required argument for the provider,
  // or handle other logic.
  factory SettingsViewModel.provider({required bool isDark}) => 
      SettingsViewModel(isDark: isDark);
}
```

## Summary

| Feature | Annotation |
| :--- | :--- |
| **Basic Provider** | `@genProvider` |
| **Arguments** | (Automatic based on constructor) |
| **Keep Alive** | `@GenProvider(aliveForever: true)` |
| **Custom Key** | `@GenProvider(key: ...)` |
| **Control Creation** | `factory ClassName.provider(...)` |
