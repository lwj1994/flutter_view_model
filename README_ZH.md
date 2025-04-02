### 视图模型（ViewModel）

* 简单且轻量。
* 无复杂技巧，基于 `StreamController` 和 `setState` 实现。
* 会跟随 `State` 的 `dispose` 方法自动释放资源。
* 可在任意有状态组件（`StatefulWidget`）间共享。

> 视图模型仅绑定到有状态组件的状态（`State`）上。我们不建议将状态绑定到无状态组件（`StatelessWidget`
> ），因为无状态组件本就不该有状态。

#### 核心概念

* **视图模型（ViewModel）**：存储状态并在状态变更时发出通知。
* **视图模型工厂（ViewModelFactory）**：指导如何创建视图模型。
* **获取视图模型（getViewModel）**：创建或获取已有的视图模型。
* **监听视图模型状态（listenViewModelState）**：在组件的状态（`Widget.State`）内监听状态变化。

#### 使用方法

首先，在 `pubspec.yaml` 文件里添加如下依赖：

```yaml
  view_model:
    git:
      url: https://github.com/lwj1994/flutter_view_model
      ref: 0.0.1
```

接着，定义一个视图模型和对应的工厂类：

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
    debugPrint("销毁 MyViewModel，状态: $state，哈希码: $hashCode");
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

然后，在有状态组件的状态类中使用视图模型：

```dart
import "package:view_model/view_model.dart";

class _State extends State<Page> with ViewModelStateMixin<Page> {
  // 建议使用 getter 来获取视图模型
  MyViewModel get viewModel =>
      getViewModel<MyViewModel>(factory: MyViewModelFactory(arg: "初始参数"));

  // 视图模型的状态
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
          Text("主视图模型状态 = ${_mainViewModel.state}"),
          Text(
            state,
            style: const TextStyle(color: Colors.red),
          ),
          FilledButton(
              onPressed: () async {
                refreshViewModel(_mainViewModel);
              },
              child: const Text("刷新主视图模型")),
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

#### 设置状态

视图模型接收一个归约函数（reducer）来更新状态。`setState` 方法支持异步操作。若你想等待操作完成，可在
`setState` 前添加 `await`：

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

#### 共享视图模型

你可以将 `singleton()` 方法返回 `true`，从而在任意有状态组件间共享同一个视图模型实例：

```dart
import "package:view_model/view_model.dart";

class MyViewModelFactory with ViewModelFactory<MyViewModel> {
  final String arg;

  MyViewModelFactory({this.arg = ""});

  @override
  MyViewModel build() {
    return MyViewModel(state: arg);
  }

  // 若为 true，则会共享同一个视图模型实例
  @override
  bool singleton() => false;
}

```

#### 监听状态变化

```dart
  @override
void initState() {
  super.initState();
  listenViewModelState<MainViewModel, String>(
    _mainViewModel,
    onChange: (String? p, String n) {
      print("主视图模型状态从 $p 变为 $n");
    },
  );
}
```

#### 刷新视图模型

这会销毁旧的视图模型并创建一个新的。不过，建议使用 getter 来获取视图模型，不然你得手动重置视图模型。

```dart
// 建议使用 getter 来获取视图模型。
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