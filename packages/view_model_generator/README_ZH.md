# view_model_generator（中文）

`view_model_generator` 是为 `view_model` 包提供的代码生成器。
它可以为你的 `ViewModel` 自动生成 `ViewModelProvider` 声明，
从而简化依赖注入与实例管理的样板代码。

## 安装

在你的 `pubspec.yaml` 中加入：

```yaml
dependencies:
  view_model: ^latest_version

dev_dependencies:
  build_runner: ^latest_version
  view_model_generator: ^latest_version
```

## 使用

- 第一步：在 `ViewModel` 类上添加注解 `@genProvider` 或
  `@GenProvider(...)`。
- 第二步：运行构建命令。

### 1. 添加注解

```dart
import 'package:view_model/view_model.dart';

part 'my_view_model.vm.dart';

@genProvider
class MyViewModel extends ViewModel {
  MyViewModel();
}
```

### 2. 运行构建

Flutter 项目：

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

纯 Dart 项目：

```bash
dart run build_runner build
```

生成的文件 `my_view_model.vm.dart` 中会包含 `myViewModelProvider`。

## 生成代码示例

为每个带注解的类生成一个全局的 `ViewModelProvider` 变量。

示例（类名 `MyViewModel`）：

```dart
final myViewModelProvider = ViewModelProvider<MyViewModel>(
  builder: () => MyViewModel(),
);
```

如果 `ViewModel` 构造函数中有依赖参数，生成器最多支持 4 个参数，
并自动生成 `ViewModelProvider.arg`、`arg2`、`arg3`、`arg4` 变体。

```dart
@genProvider
class UserViewModel extends ViewModel {
  final UserRepository repo;
  UserViewModel(this.repo);
}

// 生成代码：
final userViewModelProvider =
    ViewModelProvider.arg<UserViewModel, UserRepository>(
  builder: (UserRepository repo) => UserViewModel(repo),
);
```

## Factory 优先规则

如果类中定义了 `factory ClassName.provider(...)`，并且该 factory 的
必填参数个数与类型满足要求，生成器会优先使用这个 factory 来生成 provider。

```dart
@genProvider
class A extends Base {
  final P p;
  A({required super.s, required this.p});
  factory A.provider({required P p}) => A(s: 0, p: p);
}

// 生成代码：
final aProvider = ViewModelProvider.arg<A, P>(
  builder: (P p) => A.provider(p: p),
);
```

## 命名规则

Provider 变量名通常为 `lowerCamel(ClassName) + 'Provider'`。
特殊情况：`PostViewModel` 的变量名为 `postProvider`。

## Key / Tag 声明

可以在 `@GenProvider(...)` 中声明缓存的 `key` 和 `tag`。
两者均支持字符串与非字符串表达式。

- 字符串：`'fixed'`、`"ok"`、`r'${p.id}'`
- 对象 / 表达式：`Object()`、数字、布尔、`null`
- 表达式标记：`Expression('...')`，用于在生成的闭包中展开非字符串表达式，
  例如 `repo`、`repo.id`、`repo.compute(page)`

规则：

- 有参 Provider：`key` / `tag` 会生成与 `builder` 签名一致的闭包。
- 无参 Provider：`key` / `tag` 以常量直接插入。

示例：

```dart
// 单参，字符串模板
@GenProvider(key: r'kp-$p', tag: r'tg-$p')
class B { B({required this.p}); final P p; }

// 生成
final bProvider = ViewModelProvider.arg<B, P>(
  builder: (P p) => B(p: p),
  key: (P p) => 'kp-$p',
  tag: (P p) => 'tg-$p',
);

// 单参，嵌套插值
@GenProvider(tag: r'${p.name}', key: r'${p.id}')
class B2 { B2({required this.p}); final P p; }

// 生成：key/tag 字符串插值的闭包

// 对象常量
@GenProvider(key: Object(), tag: Object())
class C { C({required this.p}); final P p; }

// 生成：闭包中返回 Object()

// 使用 Expr 传递非字符串表达式
@GenProvider(key: Expression('repo'), tag: Expression('repo.id'))
class G { G({required this.repo}); final Repository repo; }

// 生成：非字符串表达式的闭包

// 无参 + 常量
@GenProvider(key: 'fixed', tag: Object())
class E { E(); }

// 生成：在 ViewModelProvider<E> 中直接插入常量
```

## 限制

- 最多支持 4 个必填构造参数（`arg`、`arg2`、`arg3`、`arg4`）。
- 会排除 `required super.xxx` 的转发参数，不计入 Provider 生成签名。

## 参数处理规则

- **主构造函数**：仅收集 **required** 参数。可选参数（如 `{this.id}`）会被忽略。
- **Factory `provider`**：收集 **所有** 参数（包括可选参数）。这让你可以完全控制暴露哪些参数。

示例：

```dart
@genProvider
class MyViewModel {
  final String userId;
  final bool showDetail;
  
  // 可选参数 `showDetail` 在生成 provider 时会被忽略
  MyViewModel({required this.userId, this.showDetail = false});
}
// 生成：ViewModelProvider.arg<MyViewModel, String>(...)
// `showDetail` 使用默认值

// 如需包含可选参数，请定义 factory：
@genProvider
class MyViewModel2 {
  final String userId;
  final bool showDetail;
  
  MyViewModel2({required this.userId, this.showDetail = false});
  
  // Factory provider 会包含你定义的所有参数
  factory MyViewModel2.provider({
    required String userId,
    bool showDetail = false,
  }) => MyViewModel2(userId: userId, showDetail: showDetail);
}
// 生成：ViewModelProvider.arg2<MyViewModel2, String, bool>(...)
```
