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
  final String? keyV;
  final bool isSingleton;

  TestViewModelFactory({
    this.initState = "initState",
    this.isSingleton = false,
    this.keyV,
  });

  @override
  TestViewModel build() {
    return TestViewModel(state: initState);
  }

  @override
  String? key() {
    if (keyV == null) return super.key();
    return keyV;
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

class TestStatelessViewModel extends StatelessViewModel {
  TestStatelessViewModel() {
    print("TestStatelessViewModel create : $hashCode");
  }
}

class TestStatelessViewModelFactory
    with ViewModelFactory<TestStatelessViewModel> {
  final String? keyV;
  final bool isSingleton;

  TestStatelessViewModelFactory({
    this.isSingleton = false,
    this.keyV,
  });

  @override
  TestStatelessViewModel build() {
    return TestStatelessViewModel();
  }

  @override
  String? key() {
    return keyV;
  }

  @override
  bool singleton() {
    return isSingleton;
  }
}
