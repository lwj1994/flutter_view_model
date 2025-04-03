# **ViewModel**

[English Documentation](README.md)

- **简单 & 轻量**
- **无魔法，基于 `StreamController` 和 `setState`**
- **自动释放，跟随 `State` 的 `dispose`**
- **可在任意 `StatefulWidget` 之间共享**

> **ViewModel 仅绑定到 `StatefulWidget` 的 `State`。不推荐将其绑定到 `StatelessWidget`，因为 `StatelessWidget` 不应具有状态。**

---

## **核心概念**

- **ViewModel**：存储状态并通知状态变更。
- **ViewModelFactory**：定义如何创建 `ViewModel`。
- **getViewModel**：创建或获取已有的 `ViewModel`。


---

## **使用方法**

### **安装**
```yaml
view_model:
  git:
    url: https://github.com/lwj1994/flutter_view_model
    ref: 0.0.1
```

### **创建 ViewModel**
```dart
import "package:view_model/view_model.dart";

class MyViewModel extends ViewModel<String> {
  MyViewModel({required super.state}) {
    debugPrint("创建 MyViewModel，state: $state, hashCode: $hashCode");
  }

  void setNewState() {
    setState((s) => "hi");
  }

  @override
  void dispose() async {
    super.dispose();
    debugPrint("释放 MyViewModel: $state, $hashCode");
  }
}
```

---

### **创建 ViewModel 工厂**
```dart
import "package:view_model/view_model.dart";

class MyViewModelFactory with ViewModelFactory<MyViewModel> {
  final String arg;

  MyViewModelFactory({this.arg = ""});

  @override
  MyViewModel build() {
    return MyViewModel(state: arg);
  }
}
```

---

### **在 Widget 中使用 ViewModel**
```dart
import "package:view_model/view_model.dart";

class _State extends State<Page> with ViewModelStateMixin<Page> {
  // 建议使用 getter 获取 ViewModel
  MyViewModel get viewModel =>
      getViewModel<MyViewModel>(factory: MyViewModelFactory(arg: "初始参数"));

  // 获取 ViewModel 的状态
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
                debugPrint("页面 MyViewModel hashCode = ${viewModel.hashCode}");
                debugPrint("页面 MyViewModel.state = ${viewModel.state}");
              },
              child: const Text("打印 MyViewModel")),
        ],
      ),
    );
  }
}
```

---

## **更新状态**
```dart
import "package:view_model/view_model.dart";

class MyViewModel extends ViewModel {
  void setNewStates() async {
    setState("1");
  }
}
```

---

## **共享 ViewModel**
可以设置 `singleton() => true`，在多个 `StatefulWidget` 之间共享同一个 `ViewModel` 实例。

```dart
import "package:view_model/view_model.dart";

class MyViewModelFactory with ViewModelFactory<MyViewModel> {
  final String arg;

  MyViewModelFactory({this.arg = ""});

  @override
  MyViewModel build() {
    return MyViewModel(state: arg);
  }

  // 设置为 true 共享 ViewModel 实例  
  @override
  bool singleton() => false;
}
```

---

## **监听状态变化**
```dart
@override
void initState() {
  super.initState();
  _mainViewModel.listen(onChanged: (String? prev, String state) {
    print("mainViewModel 状态变化: $prev -> $state");
  });
}
```

---

## **刷新 ViewModel**
刷新 `ViewModel` 会销毁旧的 `ViewModel` 并创建一个新的。  
建议使用 **getter 获取 `ViewModel`**，否则需要手动重置 `viewModel`。

```dart
// 推荐使用 getter 获取 ViewModel
MyViewModel get viewModel => getViewModel<MyViewModel>();

refresh() {
  // 刷新 ViewModel
  refreshViewModel(viewModel);
}
```

或者：

```dart
late MyViewModel viewModel = getViewModel<MyViewModel>(factory: factory);

refresh() {
  // 刷新并重置 ViewModel
  refreshViewModel(viewModel);
  viewModel = getViewModel<MyViewModel>(factory: factory);
}
```
