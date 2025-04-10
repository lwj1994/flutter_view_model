// @author luwenjie on 2025/4/10 17:18:49

import 'package:flutter/cupertino.dart';
import 'package:view_model/src/view_model/view_model.dart';

class StatelessState {}

abstract class StatelessViewModel extends ViewModel<StatelessState> {
  StatelessViewModel() : super(state: StatelessState());

  @override
  @protected
  Function() listen(
      {required Function(StatelessState? previous, StatelessState state)
          onChanged}) {
    return super.listen(onChanged: onChanged);
  }

  Function() addListener({required Function() onChanged}) {
    return super.listen(onChanged: (p, n) {
      onChanged.call();
    });
  }

  @protected
  void notifyListeners() {
    setState(StatelessState());
  }
}
