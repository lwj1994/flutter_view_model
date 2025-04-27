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
  MyViewModel get viewModel => getViewModel<MyViewModel>(
      factory: MyViewModelFactory(arg: "init MyViewModel"));

  // MainViewModel get _mainViewModel =>
  //     getViewModel<MainViewModel>(factory: MainViewModelFactory());

  MyState get state => viewModel.state;

  @override
  void initState() {
    super.initState();
    // listenViewModelState<MainViewModel, String>(
    //   _mainViewModel,
    //   onChange: (String? p, String n) {
    //     print("mainViewModel state change $p -> $n");
    //   },
    // );

    viewModel.listen(onChanged: (MyState? previous, MyState state) {
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
    return MyViewModel(state: MyState(name: ""));
  }
}

class MyViewModel extends ViewModel<MyState> {
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
    return 'MyState{' + ' name: $name,' + '}';
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
      'name': this.name,
    };
  }

  factory MyState.fromMap(Map<String, dynamic> map) {
    return MyState(
      name: map['name'] as String,
    );
  }

//</editor-fold>
}
