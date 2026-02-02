# view_model_generator

`view_model` 的专属代码生成器 🤖

## 😫 痛点

用 `view_model` 时，每次都要手动定义全局 `ViewModelSpec`，是不是觉得有点枯燥？

```dart
// 没用生成器 :(
final mySpec = ViewModelSpec<MyViewModel>(
  builder: () => MyViewModel(),
);
```

## 💡 解决方案

**view_model_generator** 让你告别重复劳动！一个注解，自动搞定！✨

```dart
// 用了生成器 :)
@genProvider
class MyViewModel extends ViewModel {}
```

## 📦 安装

在 `dev_dependencies` 加入它：

```yaml
dev_dependencies:
  view_model_generator: ^latest_version
  build_runner: ^latest_version
```

## 🌈 功能特性

### 1. 基础用法 👶

1.  **加注解**：给类加上 `@genProvider`。
2.  **跑命令**：`dart run build_runner build`。

```dart
import 'package:view_model/view_model.dart';
part 'my_view_model.vm.dart';

@genProvider
class MyViewModel extends ViewModel {
  MyViewModel();
}
```

这就生成了 `my_view_model.vm.dart`：

```dart
final mySpec = ViewModelSpec<MyViewModel>(
  builder: () => MyViewModel(),
);
```

生成的 Spec 名字永远是 **小驼峰类名** + `Spec`（例如 `UserViewModel` -> `userSpec`）。

### 2. 处理参数 (依赖注入) 💉

如果你的构造函数需要参数（比如 Repository 或 ID），生成器超聪明，自动识别！

```dart
@genProvider
class UserViewModel extends ViewModel {
  final int userId;
  final Repository repo;

  // 生成器会检测到这些必填参数
  UserViewModel(this.userId, this.repo);
}
```

**在 UI 中使用：**

```dart
// 1. 传参给 spec 获取 factory
final factory = userSpec(123, repository);

// 2. Watch 它
final vm = viewModelBinding.watch(factory);
```

或者一步到位：

```dart
final vm = viewModelBinding.watch(userSpec(123, repository));
```

*注意：最多支持 4 个必填参数哦！*

### 3. Alive Forever (全局单例) ♾️

想要 ViewModel 即使没人用也一直活着（比如全局 Auth 状态）？设置 `aliveForever: true`！建议配个 **固定 key**，方便全局存取。

```dart
@GenProvider(aliveForever: true, key: "AuthViewModel")
class AuthViewModel extends ViewModel {}
```

### 4. 自定义 Key 和 Tag 🏷️

你可以自定义 spec 的 `key` 和 `tag`，调试日志里看它更清晰！

```dart
@GenProvider(key: 'special_vm', tag: 'v1')
class MyViewModel extends ViewModel {}
```

还能用表达式：

```dart
@GenProvider(key: Expression('server_id'))
class ServerViewModel extends ViewModel {
  final String serverId;
  ServerViewModel(this.serverId);
}
```

### 5. 进阶：Factory 控制 🛠️

默认情况下，生成器用主构造函数，只看 **required** 参数。
想搞点花样（比如暴露可选参数，或者用命名构造函数）？定义个叫 `provider` 的 factory 就行！

```dart
@genProvider
class SettingsViewModel extends ViewModel {
  final bool isDark;
  
  // 这里 'isDark' 是可选的
  SettingsViewModel({this.isDark = false});

  // 生成器会优先用这个 factory！
  // 这样你就能把 'isDark' 变成 spec 的必填参数，或者做点别的逻辑
  factory SettingsViewModel.provider({required bool isDark}) => 
      SettingsViewModel(isDark: isDark);
}
```

## 📝 总结

| 特性 | 注解 |
| :--- | :--- |
| **基础 Spec** | `@genProvider` |
| **参数** | (自动检测构造函数) |
| **Keep Alive** | `@GenProvider(aliveForever: true)` |
| **自定义 Key** | `@GenProvider(key: ...)` |
| **控制创建** | `factory ClassName.provider(...)` |
