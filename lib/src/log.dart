// @author luwenjie on 2025/3/27 11:55:17
import 'package:flutter/foundation.dart';
import 'package:view_model/view_model.dart';

void viewModelLog(String s) {
  if (!ViewModel.logEnable) return;
  debugPrint("view_model:  $s");
}
