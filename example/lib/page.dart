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

class _State extends State<SecondPage> with ViewModelStateMixin {
  MyViewModel get viewModel =>
      watchViewModel(factory: MyViewModelFactory(arg: _dynamicArg));

  String _dynamicArg = "init MyViewModel";

  MyState get state => viewModel.state;

  @override
  void initState() {
    super.initState();
    viewModel.listenState(onChanged: (MyState? previous, MyState state) {
      print("myViewModel state change $previous -> $state");
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          viewModel.setRandomName();
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
          Text(
            "$viewModel",
            style: const TextStyle(color: Colors.red),
          ),
          FilledButton(
              onPressed: () async {
                _dynamicArg = DateTime.now().toString();
                recycleViewModel(viewModel);
              },
              child: const Text("recycle viewModel")),
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
    return MyViewModel(
      state: MyState(name: ""),
      arg: arg,
    );
  }
}

class MyViewModel extends StateViewModel<MyState> {
  final String arg;

  MyViewModel({
    required super.state,
    this.arg = "",
  }) {
    debugPrint("create $this, hashCode:$hashCode");
  }

  @override
  String toString() {
    return "(state:$state,arg:$arg)";
  }

  @override
  void dispose() async {
    super.dispose();
    debugPrint("dispose ViewModel  $hashCode");
  }

  void setRandomName() {
    setState(MyState(name: Random().nextInt(200).toString()));
  }
}

class MyState {
  final String name;

//<editor-fold desc="Data Methods">
  const MyState({
    required this.name,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MyState &&
          runtimeType == other.runtimeType &&
          name == other.name);

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() {
    return 'MyState{' ' name: $name,' '}';
  }

  MyState copyWith({
    String? name,
  }) {
    return MyState(
      name: name ?? this.name,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
    };
  }

  factory MyState.fromMap(Map<String, dynamic> map) {
    return MyState(
      name: map['name'] as String,
    );
  }

//</editor-fold>
}
