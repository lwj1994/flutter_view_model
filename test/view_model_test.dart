import 'package:flutter_test/flutter_test.dart';
import 'package:view_model/src/get_instance/manager.dart';
import 'package:view_model/view_model.dart';

import 'test_widget.dart';

void main() {
  group('stateless_view_model state', () {
    setUp(() {
      ViewModel.initConfig(ViewModelConfig(logEnable: true));
    });

    test("dispose error", () async {
      final vm = instanceManager.getNotifier(
          factory: InstanceFactory<DisposeErrorViewModel>(
              builder: () {
                return DisposeErrorViewModel();
              },
              watchId: "watchId1"));
      final vmIns = vm.instance;
      vm.recycle();

      await Future.delayed(const Duration(seconds: 1));
      assert(vm.watchIds.isEmpty);
      assert(vmIns.isDisposed);
    });

    test("batch_set_state", () async {
      final viewModel = TestStatelessViewModel();
      var c = 0;
      viewModel.addListener(onChanged: () {
        c++;
        print("batch_set_state $c");
      });

      viewModel.notifyListeners();
      viewModel.notifyListeners();
      viewModel.notifyListeners();
      await Future.delayed(const Duration(seconds: 1));
      assert(c == 3);
    });
  });
}
