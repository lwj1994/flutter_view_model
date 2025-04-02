import 'dart:math';

import 'package:auto_route/annotations.dart';
import 'package:example/route.dart';
import 'package:flutter/material.dart';
import 'package:view_model/view_model.dart';

/// @author luwenjie on 2024/7/27 23:37:23

@RoutePage()
class SecondPage extends StatefulWidget {
  final String id;

  const SecondPage(this.id, {super.key});

  @override
  State<SecondPage> createState() {
    return _State();
  }
}

enum ReducerType {
  add,
  sub,
}

class _State extends State<SecondPage> with ViewModelStateMixin {
  MyViewModel get viewModel => getViewModel<MyViewModel>(
      factory: MyViewModelFactory(arg: "init MyViewModel"));

  // MainViewModel get _mainViewModel =>
  //     getViewModel<MainViewModel>(factory: MainViewModelFactory());

  String get state => viewModel.state;

  @override
  void initState() {
    super.initState();
    // listenViewModelState<MainViewModel, String>(
    //   _mainViewModel,
    //   onChange: (String? p, String n) {
    //     print("mainViewModel state change $p -> $n");
    //   },
    // );

    listenViewModelState<MyViewModel, String>(
      viewModel,
      onChange: (String? p, String n) {
        print("myViewModel state change $p -> $n");
      },
    );

    listenViewModelAsyncState<MyViewModel, String>(
      viewModel,
      onChange: (AsyncState<String> s) {
        print("myViewModel asyncState change $s");
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    print("SecondPage trigger build(BuildContext context)");
    switch (viewModel.asyncState) {
      case AsyncLoading<String>():
        switch (viewModel.asyncState.tag as ReducerType?) {
          case ReducerType.add:
            return const Center(child: CircularProgressIndicator());
            break;
          case ReducerType.sub:
            break;
          case null:
            break;
        }
      case AsyncSuccess<String>():
        break;
      case AsyncError():
        break;
    }
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          viewModel.setId(ReducerType.add);
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
          // Text("mainViewModel.state = ${_mainViewModel.state}"),
          Text(
            "myViewModel state :$state",
            style: const TextStyle(color: Colors.red),
          ),
          FilledButton(
              onPressed: () async {
                refreshViewModel(viewModel);
              },
              child: const Text("refresh viewModel")),
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

class MyViewModelFactory with ViewModelFactory<MyViewModel> {
  final String arg;

  MyViewModelFactory({this.arg = ""});

  @override
  MyViewModel build() {
    return MyViewModel(state: arg);
  }
}

class MyViewModel extends ViewModel<String> {
  MyViewModel({
    required super.state,
  }) {
    debugPrint("create ViewModel state:$state  hashCode:$hashCode");
  }

  @override
  void dispose() async {
    super.dispose();
    debugPrint("dispose ViewModel  $hashCode");
  }

  void setId(ReducerType type) {
    state = Random().nextInt(200).toString();
  }
}
