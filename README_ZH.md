# view_model

[English README](README.md)

* 简洁轻量
* 无魔法实现，基于 `StreamController` 和 `setState`
* 自动释放资源，跟随 Widget 的 `State.dispose`
* 可在多个 `StatefulWidget` 间共享

> ViewModel 只绑定于 `StatefulWidget` 的 `State`。  
> 不推荐绑定到 `StatelessWidget`，因为它本身不应持有状态。

---

## 核心概念

* **ViewModel**：保存状态并在状态变化时通知监听者。
* **ViewModelFactory**：定义如何创建 ViewModel。
* **getViewModel**：创建或获取一个已有的 ViewModel 实例。

---

## StatefulViewModel 与 StatelessViewModel

默认情况下，`ViewModel` 是带状态的（Stateful）。

* **Stateful ViewModel**
    * 必须持有一个 `state`
    * `state` 应为不可变对象
    * 调用 `setState()` 来更新状态

* **StatelessViewModel**
    * 一个更简单的类，不持有 `state`
    * 调用 `notifyListeners()` 来通知数据更新

---

## 使用方式

```yaml
view_model:
  git:
    url: https://github.com/lwj1994/flutter_view_model
    ref: 0.0.7
```

```dart
import "package:view_model/view_model.dart";

class MyViewModel extends ViewModel<String> {
  MyViewModel({required super.state}) {
    debugPrint("创建 MyViewModel state: $state hashCode: $hashCode");
  }

  void setNewState() {
    setState((s) => "hi");
  }

  @override
  void dispose() async {
    super.dispose();
    debugPrint("销毁 MyViewModel $state $hashCode");
  }
}

class MyViewModelFactory with ViewModelFactory<MyViewModel> {
  final String arg;
  MyViewModelFactory({this.arg = ""});

  @override
  MyViewModel build() => MyViewModel(state: arg);
}
```

---

```dart
import "package:view_model/view_model.dart";

class _State extends State<Page> with ViewModelStateMixin<Page> {
  // 推荐使用 getter 获取 ViewModel
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
            child: const Text("刷新 mainViewModel"),
          ),
          FilledButton(
            onPressed: () {
              debugPrint("page.MyViewModel hashCode = ${viewModel.hashCode}");
              debugPrint("page.MyViewModel.state = ${viewModel.state}");
            },
            child: const Text("打印 MyViewModel"),
          ),
        ],
      ),
    );
  }
}
```

---

## 设置状态或通知数据变更

**Stateful ViewModel 示例：**

```dart
import "package:view_model/view_model.dart";

class MyViewModel extends ViewModel {
  void setNewStates() async {
    setState("1");
  }
}
```

**StatelessViewModel 示例：**

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

---

## 共享 ViewModel 实例

### singleton 单例共享

通过重写 `singleton() => true`，可以在多个 StateWidget 之间共享同一个 ViewModel 实例：

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

### key 键值共享

通过重写 `key()`，可指定在同一个 key 下共享 ViewModel 实例。若返回 null，则不共享：

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

---

### 获取已存在的 ViewModel

通过 `requireExistingViewModel` 获取一个已有的共享实例。若传入 `key == null`，则获取标记了 `singleton() == true` 的 ViewModel：

```dart
class _State extends State<Page> with ViewModelStateMixin<Page> {
  MyViewModel get viewModel => requireExistingViewModel<MyViewModel>(key: null);
}
```

---

## 监听状态变化

```dart
@override
void initState() {
  super.initState();
  _mainViewModel.listen(onChanged: (String? prev, String next) {
    print("mainViewModel 状态变化: $prev -> $next");
  });
}
```

---

## 刷新 ViewModel

刷新会销毁旧的 ViewModel 并创建一个新的实例。  
建议使用 getter 获取 ViewModel，否则你需要手动重置它的引用。

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
