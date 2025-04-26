# view_model 文档

[英文文档](README.md)

## 特性

- **简洁轻量**：设计精简，资源占用低。
- **原理清晰**：基于`StreamController`和`setState`构建，无复杂逻辑。
- **自动释放**：随`StatefulWidget`的`State`一同自动释放资源。
- **可共享性**：可在任意`StatefulWidget`之间共享。

> 注意：`ViewModel`仅能绑定到`StatefulWidget`的`State`。因为`StatelessWidget`不用于存储状态。

## 核心概念

- **ViewModel**：存储状态，并在状态变化时通知监听器。
- **ViewModelFactory**：规定创建`ViewModel`的方法。
- **getViewModel**：用于创建新的`ViewModel`或获取已有的`ViewModel`实例。

## 有状态与无状态的ViewModel

默认情况下，`ViewModel`是有状态的。

### 有状态的ViewModel

- 必须持有一个`state`。
- `state`应保持不可变。
- 通过调用`setState()`方法更新状态。

### 无状态的ViewModel

- 是一种更简易的方案，没有内部`state`。
- 通过调用`notifyListeners()`方法通知数据变化。

## 使用方法

### 在`pubspec.yaml`中添加依赖

```yaml
view_model:
  git:
    url: https://github.com/lwj1994/flutter_view_model
    ref: 0.0.7
```

### 在Dart中实现ViewModel

```dart
import "package:view_model/view_model.dart";

class MyViewModel extends ViewModel<String> {
  MyViewModel({required super.state}) {
    debugPrint("Created MyViewModel state: $state hashCode: $hashCode");
  }

  void setNewState() {
    setState((s) => "hi");
  }

  @override
  void dispose() async {
    super.dispose();
    debugPrint("Disposed MyViewModel $state $hashCode");
  }
}

class MyViewModelFactory with ViewModelFactory<MyViewModel> {
  final String arg;

  MyViewModelFactory({this.arg = ""});

  @override
  MyViewModel build() => MyViewModel(state: arg);
}
```

### 在Widget中使用ViewModel

```dart
import "package:view_model/view_model.dart";

class _State extends State<Page> with ViewModelStateMixin<Page> {
  // 建议使用getter获取ViewModel
  MyViewModel get viewModel =>
      getViewModel<MyViewModel>(factory: MyViewModelFactory(arg: "init arg"));

  String get state => viewModel.state;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: viewModel.setNewState,
        child: Icon(Icons.add),
      ),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => appRouter.maybePop(),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("mainViewModel.state = ${_mainViewModel.state}"),
          Text(
            state,
            style: const TextStyle(color: Colors.red),
          ),
          FilledButton(
            onPressed: () async => refreshViewModel(_mainViewModel),
            child: const Text("Refresh mainViewModel"),
          ),
          FilledButton(
            onPressed: () {
              debugPrint("page.MyViewModel hashCode = ${viewModel.hashCode}");
              debugPrint("page.MyViewModel.state = ${viewModel.state}");
            },
            child: const Text("Print MyViewModel"),
          ),
        ],
      ),
    );
  }
}
```

## 更新状态或通知变化

### 有状态的ViewModel

```dart
import "package:view_model/view_model.dart";

class MyViewModel extends ViewModel {
  void setNewStates() async {
    setState("1");
  }
}
```

### 无状态的ViewModel

```dart
import "package:view_model/view_model.dart";

class MyViewModel extends StatelessViewModel {
  String s = "1";

  void setNewStates() async {
    s = "2";
    notifyListeners();
  }
}
```

## 共享ViewModel实例

### 单例模式

设置`singleton() => true`，以在多个`StatefulWidget`之间共享同一个`MyViewModel`实例。

```dart
class MyViewModelFactory with ViewModelFactory<MyViewModel> {
  final String arg;

  MyViewModelFactory({this.arg = ""});

  @override
  MyViewModel build() => MyViewModel(state: arg);

  @override
  bool singleton() => true;
}
```

### 基于键的共享

使用`key()`方法，在具有相同键的Widget之间共享同一个`MyViewModel`。如果`key == null`
，则不会共享实例，不同的键会创建不同的实例。

例如，在`UserPage`中，`UserViewModel`实例会根据`userId`进行共享。

```dart
class MyViewModelFactory with ViewModelFactory<MyViewModel> {
  final String arg;

  MyViewModelFactory({this.arg = ""});

  @override
  MyViewModel build() => MyViewModel(state: arg);

  @override
  String? key() => "shared-key";
}
```

### 获取现有ViewModel

使用`requireExistingViewModel`获取共享实例。如果`key`为`null`，它将返回新创建的`ViewModel`。

```dart
class _State extends State<Page> with ViewModelStateMixin<Page> {
  MyViewModel get viewModel => requireExistingViewModel<MyViewModel>(key: null);
}
```

## 监听变化

```dart
@override
void initState() {
  super.initState();
  _mainViewModel.listen(onChanged: (String? prev, String next) {
    print("mainViewModel state changed: $prev -> $next");
  });
}
```

## 刷新ViewModel

刷新操作会释放旧的`ViewModel`并创建新的。建议使用getter访问`ViewModel`；否则，需要手动重置引用。

```dart
// 推荐方式
MyViewModel get viewModel => getViewModel<MyViewModel>();

void refresh() {
  refreshViewModel(viewModel);
}
```

或者：

```dart

late MyViewModel viewModel = getViewModel<MyViewModel>(factory: factory);

void refresh() {
  refreshViewModel(viewModel);
  viewModel = getViewModel<MyViewModel>(factory: factory);
}
``` 