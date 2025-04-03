// @author luwenjie on 2025/3/27 16:17:08

import 'dart:async';

import 'package:view_model/view_model.dart';

class MainViewModel extends ViewModel<String> {
  MainViewModel({required super.state}) {
    print("MainViewModel2 create : $hashCode");
    final t = Timer.periodic(Duration(seconds: 3), (t) {
      setState("update2 ${t.tick}");
    });
    addDispose(t.cancel);
  }

  @override
  void dispose() {
    super.dispose();
    print("MainViewModel2 dispose $hashCode");
  }
}

class MainViewModelFactory with ViewModelFactory<MainViewModel> {
  final String arg;

  MainViewModelFactory({this.arg = ""});

  @override
  MainViewModel build() {
    return MainViewModel(state: arg);
  }

  @override
  bool singleton() {
    return true;
  }
}
