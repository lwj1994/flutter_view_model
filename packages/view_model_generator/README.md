# view_model_generator

Code generator for the `view_model` package. This package generates `ViewModelProvider`s for your `ViewModel`s, simplifying dependency injection and instance management.

## Installation

Add `view_model` and `view_model_generator` to your `pubspec.yaml`:

```yaml
dependencies:
  view_model: ^latest_version

dev_dependencies:
  build_runner: ^latest_version
  view_model_generator: ^latest_version
```

## Usage

1.  Annotate your `ViewModel` class with `@genProvider`.
2.  Run the build runner.

### 1. Annotate

```dart
import 'package:view_model/view_model.dart';

part 'my_view_model.vm.dart';

@genProvider
class MyViewModel extends ViewModel {
  MyViewModel();
}
```

### 2. Run Build Runner

Run the following command in your terminal:

```bash
dart run build_runner build
```

This will generate a `my_view_model.vm.dart` file containing the `myViewModelProvider`.

## Generated Code

The generator creates a global `ViewModelProvider` variable for each annotated class.

For a class named `MyViewModel`, it generates:

```dart
final myViewModelProvider = ViewModelProvider<MyViewModel>(
  builder: () => MyViewModel(),
);
```

If your ViewModel has dependencies in its constructor, the generator supports up to 4 arguments and will generate `ViewModelProvider.arg1`, `ViewModelProvider.arg2`, etc.

```dart
@genProvider
class UserViewModel extends ViewModel {
  final UserRepository repo;
  UserViewModel(this.repo);
}
```

Generates:

```dart
final userViewModelProvider = ViewModelProvider.arg1<UserViewModel, UserRepository>(
  builder: (UserRepository repo) => UserViewModel(repo),
);
```
