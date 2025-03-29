# view_model

* Simple & lightweight.
* No magic, based on StreamController and setState.
* Auto-disposes, following State's dispose..
* Shareable across any StatefulWidgets.

> The ViewModel only binds to the State of a StatefulWidget. We do not recommend binding the state
> to a StatelessWidget as a StatelessWidget should not have state.

## core concept

* ViewModel: Stores the state and notifies of state changes.
* ViewModelFactory: Instructs how to create your ViewModel.
* getViewModel: Creates or retrieves an existing ViewModel.
* listenViewModelStateChanged: Listens for state changes within the Widget.State.

## usage

```yaml
  view_model:
    git:
      url: https://github.com/lwj1994/flutter_view_model
      ref: 0.0.1
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

## Share ViewModel

you can set `unique() => true` to share same ViewModel instance in any StateWidget.

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
  bool unique() => false;
}

```

## listen changed

```dart
  @override
void initState() {
  super.initState();
  listenViewModelStateChanged<MainViewModel, String>(
    _mainViewModel,
    onChange: (String? p, String n) {
      print("mainViewModel state change $p -> $n");
    },
  );
}
```

## refresh viewModel

this will dispose old _mainViewModel and recreate a new _mainViewModel.
but you must use getter to getViewModel or you need reset _mainViewModel.

```dart

// you'd better use getter to get ViewModel
MyViewModel get viewModel => getViewModel<MyViewModel>();
// refresh 
refreshViewModel(viewModel);
```

or

```dart

late MyViewModel viewModel = getViewModel<MyViewModel>(factory: factory);

// refresh and reset 
refreshViewModel(viewModel);
viewModel = getViewModel<MyViewModel>
(
factory
:
factory
);
```