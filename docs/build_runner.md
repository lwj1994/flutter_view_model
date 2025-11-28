
# ViewModel Provider Generator with `build_runner`

This document outlines a code generation solution using `build_runner` to automate the creation of `ViewModelProvider` and `ViewModelProvider.arg`/`ViewModelProvider.arg2`/`ViewModelProvider.arg3`/`ViewModelProvider.arg4`/`ViewModelProvider.arg5` .

## 1. Motivation

Manually creating `ViewModelProvider` for each `ViewModel` can be repetitive and error-prone, especially for `ViewModel`s with constructor arguments.

**Manual (Without Generator):**

```dart
// For a ViewModel without arguments
final counterProvider = ViewModelProvider(builder: () => CounterViewModel());

// For a ViewModel with arguments
final userProvider = ViewModelProvider.arg<UserViewModel, UserArgument>((arg) {
  return UserViewModel(arg);
});
```

This generator automates the process, reducing boilerplate and improving developer experience.

## 2. Solution Overview

We will introduce a `@Provide` annotation. When a `ViewModel` class is annotated with `@Provide`, a corresponding `provider` will be generated automatically.

- For a `ViewModel` with a default (no-argument) constructor, a `ViewModelProvider` will be generated.
- For a `ViewModel` with a constructor that takes one argument, a `ViewModelProvider.arg` will be
  generated.

## 3. How It Works

### Step 1: Add Dependencies

Add `build_runner` and a new `view_model_generator` package to your `pubspec.yaml`.

```yaml
dependencies:
  flutter:
    sdk: flutter
  view_model: <latest_version>

dev_dependencies:
  build_runner: ^2.10.4
  view_model_generator: <latest_version> # This package will contain the generator
```

### Step 2: Annotate Your ViewModel and add part directive

Use the `@Provide` annotation on your `ViewModel` classes.

**Example 1: ViewModel without arguments**

```dart
import 'package:view_model/view_model.dart';
part 'counter_view_model.vm.dart';

@Provide()
class CounterViewModel extends ViewModel {
  // ...
}
```

**Example 2: ViewModel with arguments**

```dart
import 'package:view_model/view_model.dart';
import 'package:view_model_annotations/view_model_annotations.dart';

class UserArgument {
  final String userId;
  UserArgument(this.userId);
}

part 'user_view_model.vm.dart';

@Provide()
class UserViewModel extends ViewModel {
  final UserArgument arg;
  UserViewModel(this.arg);
  // ...
}
```

### Step 3: Run the Code Generator

Execute the `build_runner` command in your terminal:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### Step 4: Use the Generated Code

The generator will create a new file (e.g., `xx_view_model.vm.dart`) containing the `provider`. You can then use this `provider` directly in your widgets.

**Generated Code (`counter_view_model.vm.dart`):**

```dart
// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'counter_view_model.dart';

// **************************************************************************
// ViewModelProviderGenerator
// **************************************************************************

final counterProvider = ViewModelProvider(
  builder: () => CounterViewModel(),
);
```

**Generated Code (`user_view_model.vm.dart`):**

```dart
// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_view_model.dart';

// **************************************************************************
// ViewModelProviderGenerator
// **************************************************************************

final userViewModelProvider = ViewModelProvider.arg<UserViewModel, UserArgument>(
  (arg) => UserViewModel(arg),
);
```

**Usage in a Widget:**

```dart
// For CounterViewModel
final vm = refer.watch(counterProvider);

// For UserViewModel
final userVM = refer.watch(userViewModelProvider, arg: UserArgument('123'));
```

## 4. Implementation Details

The `view_model_generator` package will contain:

- **`@Provide` annotation**: A simple class `class Provide { const Provide(); }`.
- **Generator Logic**: A `Builder` that uses the `source_gen` package to:
    1. Find all classes annotated with `@Provide`.
    2. Inspect the constructor of each annotated class.
    3. Generate the appropriate `ViewModelProvider` or `ViewModelProvider.arg` based on the constructor
       signature.

This approach provides a robust, scalable, and easy-to-use solution for managing `ViewModel` creation.
