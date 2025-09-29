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
  final Object? keyV;
  final Object? tag;
  final bool isSingleton;

  @override
  TestViewModel build() {
    return TestViewModel(state: initState);
  }

  @override
  Object? key() {
    if (keyV == null) return super.key();
    return keyV;
  }

  @override
  Object? getTag() {
    return tag;
  }

  @override
  bool singleton() {
    return isSingleton;
  }

//<editor-fold desc="Data Methods">
  const TestViewModelFactory({
    this.initState = "initState",
    this.keyV,
    this.tag,
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
    Object? keyV,
    bool? isSingleton,
    Object? tag,
  }) {
    return TestViewModelFactory(
      initState: initState ?? this.initState,
      keyV: keyV ?? this.keyV,
      tag: tag ?? this.tag,
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
    throw StateError("dispose test error");
  }
}

class TestStatelessViewModelFactory
    with ViewModelFactory<TestStatelessViewModel> {
  final Object? keyV;
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
  Object? key() {
    return keyV;
  }

  @override
  bool singleton() {
    return isSingleton;
  }
}
