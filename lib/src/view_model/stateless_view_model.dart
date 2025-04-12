// @author luwenjie on 2025/4/10 17:18:49

import 'package:flutter/cupertino.dart';
import 'package:view_model/src/view_model/view_model.dart';

abstract class StatelessViewModel extends ViewModel<String> {
  StatelessViewModel() : super(state: "");

  @override
  @protected
  Function() listen(
      {required Function(String? previous, String state) onChanged}) {
    return super.listen(onChanged: onChanged);
  }

  Function() addListener({required Function() onChanged}) {
    return super.listen(onChanged: (p, n) {
      onChanged.call();
    });
  }
}
