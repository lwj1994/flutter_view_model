# ViewModel Provider Generator

Code generator for the `view_model` package. It generates `ViewModelProvider` specs for your `ViewModel` classes.

## Installation

```yaml
dependencies:
  view_model: ^latest

dev_dependencies:
  build_runner: ^latest
  view_model_generator: ^latest
```

## Quick Start

### 1. Annotate Your ViewModel

```dart
import 'package:view_model/view_model.dart';

part 'my_view_model.vm.dart';

@genProvider
class MyViewModel extends ViewModel {
  MyViewModel();
}
```

### 2. Run Build Runner

```bash
dart run build_runner build --delete-conflicting-outputs
```

### 3. Use the Generated Provider

```dart
// Generated: myProvider
final vm = vef.watch(myProvider);
```

## Generated Code Examples

### No Arguments

```dart
@genProvider
class CounterViewModel extends ViewModel {
  int count = 0;
}

// Generates:
final counterProvider = ViewModelProvider<CounterViewModel>(
  builder: () => CounterViewModel(),
);
```

### With Arguments

Supports up to 4 constructor arguments:

```dart
@genProvider
class UserViewModel extends ViewModel {
  final String userId;
  UserViewModel(this.userId);
}

// Generates ViewModelProvider.arg:
final userViewModelProvider = ViewModelProvider.arg<UserViewModel, String>(
  builder: (String userId) => UserViewModel(userId),
);
```

### With Key/Tag

Use `@GenProvider` with `key` and `tag` for instance sharing:

```dart
@GenProvider(key: r'user-$id', tag: r'user-$id')
class UserViewModel extends ViewModel {
  final String id;
  UserViewModel(this.id);
}

// Generates closures for key/tag:
final userProvider = ViewModelProvider.arg<UserViewModel, String>(
  builder: (String id) => UserViewModel(id),
  key: (String id) => 'user-$id',
  tag: (String id) => 'user-$id',
);
```

### Using Expression()

For non-string key/tag values, use `Expression()`:

```dart
@GenProvider(key: Expression('repo'), tag: Expression('repo.id'))
class DataViewModel extends ViewModel {
  final Repository repo;
  DataViewModel({required this.repo});
}

// Generates expression closures (not string interpolation):
final dataProvider = ViewModelProvider.arg<DataViewModel, Repository>(
  builder: (Repository repo) => DataViewModel(repo: repo),
  key: (Repository repo) => repo,        // Returns the object itself
  tag: (Repository repo) => repo.id,     // Returns repo.id
);
```

### Factory Preference

If you define a `factory ClassName.provider(...)`, the generator will use it:

```dart
@genProvider
class MyViewModel extends BaseModel {
  final String name;
  
  MyViewModel({required super.baseField, required this.name});
  
  // Generator prefers this factory
  factory MyViewModel.provider({required String name}) => 
    MyViewModel(baseField: 'default', name: name);
}

// Uses factory instead of main constructor:
final myProvider = ViewModelProvider.arg<MyViewModel, String>(
  builder: (String name) => MyViewModel.provider(name: name),
);
```

## Parameter Rules

| Constructor Type | Parameters Collected |
|-----------------|---------------------|
| Main constructor | Only **required** parameters |
| `factory .provider()` | **All** parameters (including optional) |

This allows precise control over the generated provider signature.

## Naming Convention

- Provider name: `lowerCamelCase(ClassName) + 'Provider'`
- Special: `PostViewModel` → `postProvider` (removes common suffixes)

## Limits

- Maximum 4 constructor arguments (`arg`, `arg2`, `arg3`, `arg4`)
- Super forwarded params (`required super.xxx`) are excluded

## Links

- [view_model package](https://pub.dev/packages/view_model)
- [Generator README](https://github.com/lwj1994/flutter_view_model/blob/main/packages/view_model_generator/README.md)
