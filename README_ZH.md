# view_model
- 简单且轻量级。
- 无复杂机制，基于`StreamController`和`setState`实现。
- 自动释放资源，遵循`State`的`dispose`方法。
- 可在任意有状态组件（`StatefulWidget`）间共享。

> `ViewModel`仅绑定到有状态组件（`StatefulWidget`）的`State`上。我们不建议将状态绑定到无状态组件（`StatelessWidget`）上，因为无状态组件不应有状态。

## 核心概念
- `ViewModel`：存储状态并在状态改变时发出通知。
- `ViewModelFactory`：指导如何创建你的`ViewModel`。
- `getViewModel`：创建或获取已存在的`ViewModel`。
- `listenViewModelStateChanged`：监听`Widget.State`内的状态变化。

## 使用方法
### 添加依赖
```yaml
view_model:
  git:
    url: https://github.com/lwj1994/flutter_view_model
    ref: 0.0.1
```

### 定义`ViewModel`
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

### 在组件中使用`ViewModel`
```dart
import "package:view_model/view_model.dart";

class _State extends State<Page> with ViewModelStateMixin<Page> {
  // 建议使用getter来获取ViewModel
  MyViewModel get viewModel =>
      getViewModel<MyViewModel>(factory: MyViewModelFactory(arg: "初始参数"));

  // 获取ViewModel的状态
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
              child: const Text("刷新mainViewModel")),
          FilledButton(
              onPressed: () {
                debugPrint("页面的MyViewModel哈希码 = ${viewModel.hashCode}");
                debugPrint("页面的MyViewModel状态 = ${viewModel.state}");
              },
              child: const Text("打印MyViewModel")),
        ],
      ),
    );
  }
}
```

## 共享`ViewModel`
你可以设置`unique() => true`来在任意有状态组件（`StateWidget`）间共享同一个`ViewModel`实例。
```dart
import "package:view_model/view_model.dart";

class MyViewModelFactory with ViewModelFactory<MyViewModel> {
  final String arg;

  MyViewModelFactory({this.arg = ""});

  @override
  MyViewModel build() {
    return MyViewModel(state: arg);
  }

  // 如果为true，则会共享同一个viewModel实例。
  @override
  bool unique() => false;
}
```

## 监听状态变化
```dart
@override
void initState() {
  super.initState();
  listenViewModelStateChanged<MainViewModel, String>(
    _mainViewModel,
    onChange: (String? p, String n) {
      print("mainViewModel状态变化: $p -> $n");
    },
  );
}
```

## 刷新`ViewModel`
这将释放旧的`ViewModel`并创建一个新的。不过，建议使用getter来获取`ViewModel`，否则你需要手动重置`ViewModel`。
```dart
// 建议使用getter来获取ViewModel。
MyViewModel get viewModel => getViewModel<MyViewModel>();

void refresh() {
  // 刷新 
  refreshViewModel(viewModel);
}
```
或者
```dart
late MyViewModel viewModel = getViewModel<MyViewModel>(factory: factory);

void refresh() {
  // 刷新并重置 
  refreshViewModel(viewModel);
  viewModel = getViewModel<MyViewModel>(factory: factory);
}
``` 