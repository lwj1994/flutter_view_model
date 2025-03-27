import 'dart:math';

import 'package:auto_route/annotations.dart';
import 'package:example/main.dart';
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

class _State extends State<SecondPage> with ViewModelStateMixin {
  MyViewModel get viewModel => getViewModel<MyViewModel>(
      factory: MyViewModelFactory(arg: "init MyViewModel"));

  MainViewModel get _mainViewModel =>
      getViewModel<MainViewModel>(factory: MainViewModelFactory());

  String get state => viewModel.state;

  @override
  void initState() {
    super.initState();
    listenViewModelStateChanged<MainViewModel, String>(
      _mainViewModel,
      onChange: (String? p, String n) {
        print("mainViewModel state change $p -> $n");
      },
    );

    listenViewModelStateChanged<MyViewModel, String>(
      viewModel,
      onChange: (String? p, String n) {
        print("myViewModel state change $p -> $n");
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          viewModel.setId();
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
            "myViewModel state :$state",
            style: const TextStyle(color: Colors.red),
          ),
          FilledButton(
              onPressed: () async {
                refreshViewModel(_mainViewModel);
              },
              child: const Text("refresh mainViewModel")),
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

  void setId() {
    setState((s) async {
      return Random().nextInt(200).toString();
    });
  }
}
