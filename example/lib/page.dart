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
  MyViewModel get viewModel => getViewModel<MyViewModel>(factory: () {
    return MyViewModel(state: 'state', id: 'id');
  });

  MainViewModel get _mainViewModel => getViewModel<MainViewModel>(key: "share");

  String get state => viewModel.state;

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
            "myViewModel state :" + state,
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

class MyViewModel extends ViewModel<String> {
  final String id;

  MyViewModel({
    required super.state,
    required this.id,
  }) {
    debugPrint("create ViewModel state:$state id:$id hashCode:$hashCode");
  }

  @override
  void dispose() async {
    super.dispose();
    debugPrint("dispose ViewModel $id $hashCode");
  }


  void setId() {
    setState((s) async {
      return Random().nextInt(200).toString();
    });
  }
}
