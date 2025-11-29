# view_model_generator

Code generator for the `view_model` package. It generates
`ViewModelProvider` specs for your `ViewModel` classes to simplify DI
and instance management.

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

1. Annotate your `ViewModel` class with `@genProvider` or
   `@GenProvider(...)`.
2. Run build runner.

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

```bash
dart run build_runner build --delete-conflicting-outputs
```


This generates `my_view_model.vm.dart` which contains `myProvider`.

## Generated Code

The generator creates a global `ViewModelProvider` variable for each
annotated class.

For a class named `MyViewModel`:

```dart
final myProvider = ViewModelProvider<MyViewModel>(
  builder: () => MyViewModel(),
);
```

If your `ViewModel` has constructor dependencies, the generator supports
up to 4 arguments and will generate `ViewModelProvider.arg`,
`ViewModelProvider.arg2`, `arg3`, `arg4`.

```dart
@genProvider
class UserViewModel extends ViewModel {
  final UserRepository repo;
  UserViewModel(this.repo);
}

// Generates
final userViewModelProvider =
    ViewModelProvider.arg<UserViewModel, UserRepository>(
  builder: (UserRepository repo) => UserViewModel(repo),
);
```

### Factory preference

If your class defines `factory ClassName.provider(...)`, the generator
prefers this factory when building providers, provided the factory
matches the required constructor argument count.

```dart
@genProvider
class A extends Base {
  final P p;
  A({required super.s, required this.p});
  factory A.provider({required P p}) => A(s: 0, p: p);
}

// Generates
final aProvider = ViewModelProvider.arg<A, P>(
  builder: (P p) => A.provider(p: p),
);
```

### Special naming rule

The provider variable name is `lowerCamel(ClassName) + 'Provider'`.
Special case: `PostViewModel` becomes `postProvider`.

## Key / Tag declarations

You can declare cache `key` and `tag` in `@GenProvider(...)`. Both accept
string literals and non-string expressions.

- Strings: `'fixed'`, `"ok"`, `r'${p.id}'`.
- Objects/expressions: `Object()`, numbers, booleans, `null`.
- Expressions marker: `Expression('...')` to unwrap non-string code into
  builder closures (e.g. `repo`, `repo.id`, `repo.compute(page)`).

Rules:

- For providers with arguments, `key`/`tag` are emitted as closures with
  the same signature as `builder`.
- For providers without arguments, `key`/`tag` are emitted as constants
  directly.

Examples:

```dart
// Single arg, string templates
@GenProvider(key: r'kp-$p', tag: r'tg-$p')
class B { B({required this.p}); final P p; }

// Generates
final bProvider = ViewModelProvider.arg<B, P>(
  builder: (P p) => B(p: p),
  key: (P p) => 'kp-$p',
  tag: (P p) => 'tg-$p',
);

// Single arg, nested interpolation
@GenProvider(tag: r'${p.name}', key: r'${p.id}')
class B2 { B2({required this.p}); final P p; }

// Generates tag/key closures with string interpolation

// Object constants
@GenProvider(key: Object(), tag: Object())
class C { C({required this.p}); final P p; }

// Generates closures returning Object()

// Expressions via Expr
@GenProvider(key: Expression('repo'), tag: Expression('repo.id'))
class G { G({required this.repo}); final Repository repo; }

// Generates non-string expression closures

// No-arg provider with constants
@GenProvider(key: 'fixed', tag: Object())
class E { E(); }

// Generates constants directly in ViewModelProvider<E>
```

## Limits

- Supports up to 4 required constructor arguments (`arg`, `arg2`,
  `arg3`, `arg4`).
- Super forwarded params (`required super.xxx`) are excluded from
  provider argument signature.
