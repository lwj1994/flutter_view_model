# view_model

[中文文档](README_ZH.md)

* Simple & lightweight.
* No magic – built on top of `StreamController` and `setState`.
* Automatically disposes alongside the widget's `State`.
* Shareable across any `StatefulWidget`.

> ViewModel only binds to the `State` of a `StatefulWidget`.  
> We do not recommend binding it to a `StatelessWidget`, as `StatelessWidget`s are not meant to hold state.

---

## Core Concepts

* **ViewModel**: Holds state and notifies listeners of state changes.
* **ViewModelFactory**: Defines how to create your ViewModel.
* **getViewModel**: Creates or retrieves an existing ViewModel.

---

## StatefulViewModel and StatelessViewModel

By default, `ViewModel` is stateful.

* **Stateful ViewModel**
    * Must hold a `state`.
    * The `state` should be immutable.
    * Call `setState()` to update the state.

* **StatelessViewModel**
    * A simpler alternative without internal `state`.
    * Call `notifyListeners()` to notify data changes.

---

## Usage

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

---

```dart
import "package:view_model/view_model.dart";

class _State extends State<Page> with ViewModelStateMixin<Page> {
  // Recommended to use a getter for ViewModel
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

---

## Set State or Notify Change

**Stateful ViewModel**

```dart
import "package:view_model/view_model.dart";

class MyViewModel extends ViewModel {
  void setNewStates() async {
    setState("1");
  }
}
```

**StatelessViewModel**

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

## Sharing ViewModel Instances

### Singleton

Use `singleton() => true` to share the same ViewModel instance across multiple `StatefulWidget`s.

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

### Key-based Sharing

Use `key()` to share the same ViewModel across widgets with the same key. If `key == null`, the instance won't be shared.

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

### Requiring an Existing ViewModel

Use `requireExistingViewModel` to retrieve a shared instance. If `key` is null, it will return the ViewModel with `singleton() == true`.

```dart
class _State extends State<Page> with ViewModelStateMixin<Page> {
  MyViewModel get viewModel => requireExistingViewModel<MyViewModel>(key: null);
}
```

---

## Listening for Changes

```dart
@override
void initState() {
  super.initState();
  _mainViewModel.listen(onChanged: (String? prev, String next) {
    print("mainViewModel state changed: $prev -> $next");
  });
}
```

---

## Refreshing the ViewModel

Refreshing disposes the old ViewModel and creates a new one.  
It’s recommended to use a getter for ViewModel access—otherwise, you’ll need to manually reset the reference.

```dart
// Recommended way
MyViewModel get viewModel => getViewModel<MyViewModel>();

void refresh() {
  refreshViewModel(viewModel);
}
```

Or:

```dart
late MyViewModel viewModel = getViewModel<MyViewModel>(factory: factory);

void refresh() {
  refreshViewModel(viewModel);
  viewModel = getViewModel<MyViewModel>(factory: factory);
}
```

---

如需继续写中文文档或调整风格，随时告诉我！