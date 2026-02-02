import 'package:flutter/material.dart';
import 'package:view_model/src/view_model/state_store.dart';
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
      viewModelBinding.watch<TestViewModel>(widget.factory);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [Text(_viewModel.state)],
    );
  }
}

class TestViewModelFactory with ViewModelFactory<TestViewModel> {
  final String initState;
  final Object? keyV;
  final Object? tagV;

  @override
  TestViewModel build() {
    return TestViewModel(state: initState);
  }

  @override
  Object? key() {
    return keyV;
  }

  @override
  Object? tag() {
    return tagV;
  }

//<editor-fold desc="Data Methods">
  const TestViewModelFactory({
    this.initState = "initState",
    this.keyV,
    this.tagV,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TestViewModelFactory &&
          runtimeType == other.runtimeType &&
          initState == other.initState &&
          keyV == other.keyV);

  @override
  int get hashCode => initState.hashCode ^ keyV.hashCode;

  @override
  String toString() {
    return 'TestViewModelFactory{ initState: $initState, keyV: $keyV,}';
  }

  TestViewModelFactory copyWith({
    String? initState,
    Object? keyV,
    Object? tagV,
  }) {
    return TestViewModelFactory(
      initState: initState ?? this.initState,
      keyV: keyV ?? this.keyV,
      tagV: tagV ?? this.tagV,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'initState': initState,
      'keyV': keyV,
    };
  }

  factory TestViewModelFactory.fromMap(Map<String, dynamic> map) {
    return TestViewModelFactory(
      initState: map['initState'] as String,
      keyV: map['keyV'] as String,
    );
  }

//</editor-fold>
}

class TestViewModel extends StateViewModel<String> {
  String name = "";

  TestViewModel({required super.state}) {
    debugPrint("TestViewModel create : $hashCode");
  }
}

class TestStatelessViewModel extends ViewModel {
  TestStatelessViewModel() {
    debugPrint("TestStatelessViewModel create : $hashCode");
  }
}

class DisposeErrorViewModel extends ViewModel {
  DisposeErrorViewModel() {
    debugPrint("DisposeErrorViewModel create : $hashCode");
  }

  @override
  void dispose() {
    super.dispose();
    throw ViewModelError("dispose test error");
  }
}

class TestStatelessViewModelFactory
    with ViewModelFactory<TestStatelessViewModel> {
  final Object? keyV;

  TestStatelessViewModelFactory({
    this.keyV,
  });

  @override
  TestStatelessViewModel build() {
    return TestStatelessViewModel();
  }

  @override
  Object? key() {
    return keyV;
  }
}
