// @author luwenjie on 2025/4/27 14:07:07

import 'package:flutter_test/flutter_test.dart';

import 'get_instance_test.dart' as get_instance_test;
import 'state_widget_test.dart' as state_widget_test;
import 'stateless_view_model_test.dart' as stateless_view_model_test;
import 'view_model_test.dart' as view_model_test;

void main() {
  group('view_model tests', () {
    get_instance_test.main();
    state_widget_test.main();
    stateless_view_model_test.main();
    view_model_test.main();
  });
}
