import 'package:flutter_test/flutter_test.dart';
import 'package:view_model/view_model.dart';

import 'test_widget.dart';

void main() {
  group('stateless_view_model state', () {
    late TestStatelessViewModel viewModel;
    setUp(() {
      ViewModel.logEnable = false;
      viewModel = TestStatelessViewModel();
    });

    test("batch_set_state", () async {
      var c = 0;
      viewModel.addListener(onChanged: () {
        c++;
      });

      viewModel.notifyListeners();
      viewModel.notifyListeners();
      viewModel.notifyListeners();
      await Future.delayed(const Duration(seconds: 1));
      assert(c == 3);
    });
  });
}
