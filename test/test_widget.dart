import 'package:flutter/material.dart';
import 'package:view_model/view_model.dart';

class TestPage extends StatefulWidget {
  final TestViewModelFactory factory;

  const TestPage({super.key, required this.factory});

  @override
  State<StatefulWidget> createState() {
    return TestPageState();
  }
}

class TestPageState extends State<TestPage> with ViewModelStateMixin {
  TestViewModel get _viewModel =>
      getViewModel<TestViewModel>(factory: widget.factory);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [Text(_viewModel.state)],
    );
  }
}

class TestViewModelFactory with ViewModelFactory<TestViewModel> {
  final String initState;
  final bool isSingleton;

  TestViewModelFactory(
      {this.initState = "initState", this.isSingleton = false});

  @override
  TestViewModel build() {
    return TestViewModel(state: initState);
  }

  @override
  bool singleton() {
    return isSingleton;
  }
}

class TestViewModel extends ViewModel<String> {
  TestViewModel({required super.state}) {
    print("TestViewModel create : $hashCode");
  }
}
