# view_model_generator

Code generator for the `view_model` package.

## Overview

When using `view_model`, you need to define a `ViewModelProvider` for each ViewModel. **view_model_generator** automates this by generating the provider from a simple annotation.

**Before:**
```dart
final myProvider = ViewModelProvider<MyViewModel>(
  builder: () => MyViewModel(),
);
```

**After:**
```dart
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

Add `@genProvider` to your ViewModel class and run `dart run build_runner build`:

```dart
import 'package:view_model/view_model.dart';
part 'my_view_model.vm.dart';

@genProvider
class MyViewModel extends ViewModel {
  MyViewModel();
}
```

This generates `my_view_model.vm.dart` with a camelCase provider (e.g., `UserViewModel` -> `userProvider`):

```dart
final myProvider = ViewModelProvider<MyViewModel>(
  builder: () => MyViewModel(),
);
```

### 2. Dependency Injection

The generator detects constructor parameters and creates a provider that accepts them:

```dart
@genProvider
class UserViewModel extends ViewModel {
  final int userId;
  final Repository repo;
  UserViewModel(this.userId, this.repo);
}
```

**Usage:**

```dart
final vm = vef.watch(userProvider(123, repository));
```

*Supports up to 4 required parameters.*

### 3. Singleton Mode

Keep a ViewModel alive even when no widgets use it (useful for global stores):

```dart
@GenProvider(aliveForever: true, key: "AuthViewModel")
class AuthViewModel extends ViewModel {}
```

### 4. Custom Keys and Tags

Customize `key` and `tag` for debugging or instance identification:

```dart
@GenProvider(key: 'special_vm', tag: 'v1')
class MyViewModel extends ViewModel {}

// Dynamic keys using expressions
@GenProvider(key: Expression('server_id'))
class ServerViewModel extends ViewModel {
  final String serverId;
  ServerViewModel(this.serverId);
}
```

### 5. Custom Factory

Override default creation logic by defining a `provider` factory:

```dart
@genProvider
class SettingsViewModel extends ViewModel {
  final bool isDark;
  SettingsViewModel({this.isDark = false});

  // Generator uses this instead of the constructor
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
