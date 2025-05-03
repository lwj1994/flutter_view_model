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
      watchViewModel<TestViewModel>(factory: widget.factory);

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

//<editor-fold desc="Data Methods">
  const TestViewModelFactory({
    this.initState = "initState",
    this.keyV,
    this.isSingleton = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TestViewModelFactory &&
          runtimeType == other.runtimeType &&
          initState == other.initState &&
          keyV == other.keyV &&
          isSingleton == other.isSingleton);

  @override
  int get hashCode => initState.hashCode ^ keyV.hashCode ^ isSingleton.hashCode;

  @override
  String toString() {
    return 'TestViewModelFactory{ initState: $initState, keyV: $keyV, isSingleton: $isSingleton,}';
  }

  TestViewModelFactory copyWith({
    String? initState,
    String? keyV,
    bool? isSingleton,
  }) {
    return TestViewModelFactory(
      initState: initState ?? this.initState,
      keyV: keyV ?? this.keyV,
      isSingleton: isSingleton ?? this.isSingleton,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'initState': initState,
      'keyV': keyV,
      'isSingleton': isSingleton,
    };
  }

  factory TestViewModelFactory.fromMap(Map<String, dynamic> map) {
    return TestViewModelFactory(
      initState: map['initState'] as String,
      keyV: map['keyV'] as String,
      isSingleton: map['isSingleton'] as bool,
    );
  }

//</editor-fold>
}

class TestViewModel extends StateViewModel<String> {
  String name = "";
  TestViewModel({required super.state}) {
    print("TestViewModel create : $hashCode");
  }
}

class TestStatelessViewModel extends ViewModel {
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
