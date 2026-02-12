# view_model_generator

Generate `ViewModelSpec` code from annotations for `view_model`.

## Idea

You write a ViewModel class, the generator writes the spec for you.

```dart
final counterSpec = ViewModelSpec<CounterViewModel>(
  builder: () => CounterViewModel(),
);
```

```dart
@GenSpec
class CounterViewModel extends ViewModel {}
```

## Installation

```yaml
dev_dependencies:
  view_model_generator: ^15.0.0-dev.3
  build_runner: ^2.7.1

dependencies:
  view_model_annotation: ^15.0.0-dev.3
```

## Basic Flow

```dart
import 'package:view_model/view_model.dart';
import 'package:view_model_annotation/view_model_annotation.dart';

part 'my_view_model.vm.dart';

@GenSpec
class MyViewModel extends ViewModel {
  MyViewModel();
}
```

```bash
dart run build_runner build
```

## Naming

The spec variable name is derived from the class name:

- `UserViewModel` -> `userSpec`
- `CartStore` -> `cartStoreSpec`

## Arguments

Required constructor parameters become `arg`, `arg2`, `arg3`, or `arg4`.

```dart
@GenSpec
class UserViewModel extends ViewModel {
  final int userId;
  final Repository repo;

  UserViewModel(this.userId, this.repo);
}
```

```dart
final vm = viewModelBinding.watch(userSpec(123, repository));
```

Rules:

- Up to 4 required parameters are supported
- If `factory spec(...)` exists, it is used instead of the constructor
- For `spec(...)`, required and optional parameters are included

## Keep Alive

```dart
@GenSpec(aliveForever: true, key: 'AuthGlobal')
class AuthViewModel extends ViewModel {}
```

If the spec has arguments, `aliveForever` is generated as a closure.

## Key and Tag

Use raw string templates to emit interpolation:

```dart
@GenSpec(key: r'${p.id}', tag: r'${p.name}')
class ProfileViewModel extends ViewModel {
  final Profile p;

  ProfileViewModel(this.p);
}
```

Use `Expression` for non-string expressions:

```dart
@GenSpec(key: Expression('repo'), tag: Expression('repo.id'))
class RepoViewModel extends ViewModel {
  final Repository repo;

  RepoViewModel(this.repo);
}
```

## Custom Factory

```dart
@GenSpec
class SettingsViewModel extends ViewModel {
  final bool isDark;

  SettingsViewModel({this.isDark = false});

  factory SettingsViewModel.spec({required bool isDark}) {
    return SettingsViewModel(isDark: isDark);
  }
}
```

## Notes


- Classes without an unnamed constructor or spec factory are skipped
