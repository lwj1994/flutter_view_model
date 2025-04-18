# view_model

[中文文档](README_ZH.md)

* Simple & lightweight.
* No magic, based on StreamController and setState.
* Auto-disposes, following State's dispose.
* Shareable across any StatefulWidgets.

> The ViewModel only binds to the State of a StatefulWidget. We do not recommend binding the state
> to a StatelessWidget as a StatelessWidget should not have state.

## core concept

* ViewModel: Stores the state and notifies of state changes.
* ViewModelFactory: Instructs how to create your ViewModel.
* getViewModel: Creates or retrieves an existing ViewModel.

## usage

```yaml
  view_model:
    git:
      url: https://github.com/lwj1994/flutter_view_model
      ref: 0.0.7
```

```dart
import "package:view_model/view_model.dart";

class MyViewModel extends ViewModel<String> {

  MyViewModel({
    required super.state,
  }) {
    debugPrint("create MyViewModel state:$state hashCode:$hashCode");
  }

  void setNewState() {
    setState((s) {
      return "hi";
    });
  }

  @override
  void dispose() async {
    super.dispose();
    debugPrint("dispose MyViewModel $state $hashCode");
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

```dart
import "package:view_model/view_model.dart";

class _State extends State<Page> with ViewModelStateMixin<Page> {
  // you'd better use getter to get ViewModel
  MyViewModel get viewModel =>
      getViewModel<MyViewModel>(factory: MyViewModelFactory(arg: "init arg"));

  // viewModel's state
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
              child: const Text("refresh mainViewModel")),
          FilledButton(
              onPressed: () {
                debugPrint("page.MyViewModel hashCode = ${viewModel.hashCode}");
                debugPrint("page.MyViewModel.state = ${viewModel.state}");
              },
              child: const Text("print MyViewModel")),
        ],
      ),
    );
  }
}
```

## Set State

```dart
import "package:view_model/view_model.dart";

class MyViewModel extends ViewModel {

  void setNewStates() async {
    setState("1");
  }
}
```

## Share ViewModel

### singleton

You can set singleton() => true to share the same Type ViewModel instance across any StateWidget.

```dart
import "package:view_model/view_model.dart";

class MyViewModelFactory with ViewModelFactory<MyViewModel> {
  final String arg;

  MyViewModelFactory({this.arg = ""});

  @override
  MyViewModel build() {
    return MyViewModel(state: arg);
  }

  // if true will share same viewModel instance.  
  @override
  bool singleton() => false;
}
```

### key

You can set key() to share the same ViewModel instance across any StateWidget. if key == null, will
not share.

```dart
import "package:view_model/view_model.dart";

class MyViewModelFactory with ViewModelFactory<MyViewModel> {
  final String arg;

  MyViewModelFactory({this.arg = ""});

  @override
  MyViewModel build() {
    return MyViewModel(state: arg);
  }

  // if true will share same viewModel instance.  
  @override
  String? key() => "key";
}
```

### require exiting viewModel

require exiting viewModel by key, if key is null will get viewModel which declare `single() == true`
in factory.

```dart
class _State extends State<Page> with ViewModelStateMixin<Page> {
  // you'd better use getter to get ViewModel
  MyViewModel get viewModel =>
      requireExistingViewModel<MyViewModel>(key: null);
}
```

## Listening for Changes

```dart
  @override
void initState() {
  super.initState();
  _mainViewModel.listen(onChanged: (String? p, String state) {
    print("mainViewModel state change $p -> $state");
  },
  );
}
```

## Refreshing the ViewModel

This will dispose of the old viewModel and create a new one. However, It is recommended to use a
getter to
obtain the ViewModel, or you need to reset viewModel.

```dart
// It is recommended to use a getter to obtain the ViewModel.
MyViewModel get viewModel => getViewModel<MyViewModel>();

refresh() {
  // refresh 
  refreshViewModel(viewModel);
}

```

or

```dart

late MyViewModel viewModel = getViewModel<MyViewModel>(factory: factory);

refresh() {
  // refresh and reset 
  refreshViewModel(viewModel);
  viewModel = getViewModel<MyViewModel>(factory: factory);
}

```





