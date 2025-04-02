# 视图模型（ViewModel）

* 简单且轻量。
* 无复杂机制，基于 `StreamController` 和 `setState` 实现。
* 自动释放资源，会跟随 `State` 的 `dispose` 方法一同释放。
* 可在任意 `StatefulWidget` 间共享。

> `ViewModel` 仅绑定到 `StatefulWidget` 的 `State` 上。我们不建议将状态绑定到 `StatelessWidget` 上，因为
`StatelessWidget` 不应拥有状态。

## 核心概念

* `ViewModel`：存储状态并在状态改变时发出通知。
* `ViewModelFactory`：指导如何创建 `ViewModel`。
* `getViewModel`：创建或获取已有的 `ViewModel`。
* `listenViewModelState`：在 `Widget.State` 内监听状态变化。

## 使用方法

### 依赖配置

```yaml
  view_model:
    git:
      url: https://github.com/lwj1994/flutter_view_model
      ref: 0.0.1
```

### 定义 `ViewModel`

```dart
import "package:view_model/view_model.dart";

class MyViewModel extends ViewModel<String> {

  MyViewModel({
    required super.state,
  }) {
    debugPrint("创建 MyViewModel，状态: $state，哈希码: $hashCode");
  }

  void setNewState() {
    setState((s) {
      return "hi";
    });
  }

  @override
  void dispose() async {
    super.dispose();
    debugPrint("释放 MyViewModel，状态: $state，哈希码: $hashCode");
  }
}


class MyViewModelFactory with ViewModelFactory<MyViewModel> {
  final String arg;

  MyViewModelFactory({this.arg = ""});

  @override
  MyViewModel build() {
    return MyViewModel(state: arg);
  }
}
```

### 在 `State` 中使用 `ViewModel`

```dart
import "package:view_model/view_model.dart";

class _State extends State<Page> with ViewModelStateMixin<Page> {
  // 建议使用 getter 来获取 ViewModel
  MyViewModel get viewModel =>
      getViewModel<MyViewModel>(factory: MyViewModelFactory(arg: "初始参数"));

  // 获取 viewModel 的状态
  String get state => viewModel.state;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          viewModel.setNewState();
        },
        child: Icon(Icons.add),
      ),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            appRouter.maybePop();
          },
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
              onPressed: () async {
                refreshViewModel(_mainViewModel);
              },
              child: const Text("刷新 mainViewModel")),
          FilledButton(
              onPressed: () {
                debugPrint("页面的 MyViewModel 哈希码 = ${viewModel.hashCode}");
                debugPrint("页面的 MyViewModel 状态 = ${viewModel.state}");
              },
              child: const Text("打印 MyViewModel")),
        ],
      ),
    );
  }
}
```

## 设置状态

`ViewModel` 接收一个归约函数（reducer）来更新状态。`setState` 支持异步操作。
如果你想等待操作完成，可以在 `setState` 前添加 `await`。

```dart
import "package:view_model/view_model.dart";

class MyViewModel extends ViewModel {

  void setNewStates() async {
    // 异步操作
    setState((s) async {
      await Future.delayed(const Duration(seconds: 1));
      return AsyncSuccess(state: "1");
    });

    // 等待操作完成
    await setState((s) {
      return AsyncSuccess.success("2");
    });
  }
}
```

尽管第一个归约函数是异步的且延迟 1 秒，但状态会按照归约函数的调用顺序排列。
状态变化顺序为 [1] -> [2]。

## 共享 `ViewModel`

你可以将 `singleton()` 方法返回 `true`，从而在任意 `StateWidget` 间共享同一个 `ViewModel` 实例。

```dart
import "package:view_model/view_model.dart";

class MyViewModelFactory with ViewModelFactory<MyViewModel> {
  final String arg;

  MyViewModelFactory({this.arg = ""});

  @override
  MyViewModel build() {
    return MyViewModel(state: arg);
  }

  // 如果返回 true，则会共享同一个 viewModel 实例。  
  @override
  bool singleton() => false;
}

```

## 监听状态变化

```dart
  @override
void initState() {
  super.initState();
  listenViewModelState<MainViewModel, String>(
    _mainViewModel,
    onChange: (String? p, String n) {
      print("mainViewModel 状态从 $p 变为 $n");
    },
  );
}
```

## 刷新 `ViewModel`

这会释放旧的 `ViewModel` 并创建一个新的。不过，建议使用 getter 来获取 `ViewModel`，否则你需要手动重置
`ViewModel`。

```dart
// 建议使用 getter 来获取 ViewModel。
MyViewModel get viewModel => getViewModel<MyViewModel>();

refresh() {
  // 刷新 
  refreshViewModel(viewModel);
}

```

或者

```dart

late MyViewModel viewModel = getViewModel<MyViewModel>(factory: factory);

refresh() {
  // 刷新并重置 
  refreshViewModel(viewModel);
  viewModel = getViewModel<MyViewModel>(factory: factory);
}

```