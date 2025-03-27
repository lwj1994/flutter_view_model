# view_model

* Simple and lightweight ViewModel designed specifically for Flutter
* No any magic, just base on StreamController and setState
* Auto dispose. it will auto follow State's dispose
* Unbind BuildContext, unbind Widget tree
* SetState all Widget tree. but don't care this. because Widget tree just a configuration, no performance cost.

```dart
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

  // share same viewModel instance with key. if null will not share
  @override
  String? get key => null;
}
```

```dart
class _State extends State<Page> with ViewModelStateMixin<Page> {
  // you'd better use getter to get ViewModel
  MyViewModel get viewModel =>
      getViewModel<MyViewModel>(factory: MyViewModelFactory(arg: "init arg"));

  // viewModel's state
  String get state => viewModel.state;

  @override
  Widget buildPage(BuildContext context) {
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
              child: const Text("invalide with change id")),
          FilledButton(
              onPressed: () {
                debugPrint("page._viewModel hashCode = ${viewModel.hashCode}");
                debugPrint("page.state = ${viewModel.state}");
              },
              child: const Text("print viewmodel")),
        ],
      ),
    );
  }
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
refreshViewModel(_mainViewModel);
```

or 

```dart

late MyViewModel  viewModel = getViewModel<MyViewModel>();

// refresh and reset 
refreshViewModel(_mainViewModel);
viewModel = getViewModel<MyViewModel>(key: "key");
```