# view_model
![Static Badge](https://img.shields.io/badge/pub-0.3.0-brightgreen)

[Chinese Documentation](README_ZH.md)


> Huge thanks to [Miolin](https://github.com/Miolin) for entrusting me with
> the [view_model](https://pub.dev/packages/view_model) ! Your support
> means a lot, and I’m excited to continue its development. Appreciate it!

## Features

- **Simple and lightweight**: It features a concise design with minimal resource consumption.
- **No hidden magic**: Built upon `StreamController` and `setState`, its logic is clear and easy to
  understand.
- **Automatic disposal**: Automatically releases resources along with the `State` of a
  `StatefulWidget`.
- **Shareable**: Can be shared among any `StatefulWidget`s.

> Note: `ViewModel` can only be bound to the `State` of a `StatefulWidget`. `StatelessWidget`s are
> not designed to hold state.

## Core Concepts

- **ViewModel**: Responsible for holding state and notifying listeners when the state changes.
- **ViewModelFactory**: Defines the way to create `ViewModel`s.
- **getViewModel**: Used to create a new `ViewModel` or retrieve an existing `ViewModel` instance.

## Stateful and Stateless ViewModels

By default, `ViewModel` is stateful.

### Stateful ViewModel

- Must hold a `state`.
- The `state` should be immutable.
- Update the state by calling the `setState()` method.

### Stateless ViewModel

- A simpler alternative without an internal `state`.
- Notify of data changes by calling `notifyListeners()`.

## Usage

### Add Dependency in `pubspec.yaml`

```yaml
view_model: ${latest_version}
```

### Implement ViewModel in Dart

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

### Use ViewModel in Widget

```dart
import "package:view_model/view_model.dart";

class _State extends State<Page> with ViewModelStateMixin<Page> {
  // It is recommended to use a getter for ViewModel
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

## Updating State or Notifying Changes

### For Stateful ViewModel

```dart
import "package:view_model/view_model.dart";

class MyViewModel extends ViewModel {
  void setNewStates() async {
    setState("1");
  }
}
```

### For Stateless ViewModel

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

## Sharing ViewModel Instances

### Singleton

Set `singleton() => true` to share the same `MyViewModel` instance across multiple `StatefulWidget`
s.

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

Use `key()` to share the same `MyViewModel` among widgets with the same key. If `key == null`, the
instance won't be shared, and different keys will create different instances.

For example, in `UserPage`, the `UserViewModel` instance is shared based on the `userId`.

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

### Retrieving an Existing ViewModel

Use `requireExistingViewModel` to retrieve a shared instance. If `key` is null, it will return the
newly created `ViewModel`.

```dart
class _State extends State<Page> with ViewModelStateMixin<Page> {
  MyViewModel get viewModel => requireExistingViewModel<MyViewModel>(key: null);
}
```

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

## Refreshing the ViewModel

Refreshing disposes of the old `ViewModel` and creates a new one. It's recommended to use a getter
for accessing the `ViewModel`; otherwise, you'll need to manually reset the reference.

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