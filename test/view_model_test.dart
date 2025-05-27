import 'package:flutter_test/flutter_test.dart';
import 'package:view_model/src/get_instance/manager.dart';
import 'package:view_model/src/get_instance/store.dart';
import 'package:view_model/view_model.dart';

import 'test_widget.dart';

class MyViewModelLifecycle extends ViewModelLifecycle {
  @override
  void onAddWatcher(ViewModel viewModel, InstanceArg arg, String? newWatchId) {
    print("MyViewModelLifecycle onAddWatcher $viewModel $arg $newWatchId");
  }

  @override
  void onCreate(ViewModel viewModel, InstanceArg arg) {
    print("MyViewModelLifecycle onCreate $viewModel  $arg");
  }

  @override
  void onDispose(ViewModel viewModel, InstanceArg arg) {
    print("MyViewModelLifecycle onDispose $viewModel    $arg");
  }

  @override
  void onRemoveWatcher(
      ViewModel viewModel, InstanceArg arg, String? removedWatchId) {
    print(
        "MyViewModelLifecycle onRemoveWatcher $viewModel $arg $removedWatchId");
  }
}

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
        arg: const InstanceArg(watchId: "watchId1"),
      ));
      final vmIns = vm.instance;
      vm.recycle();

      await Future.delayed(const Duration(seconds: 1));
      assert(vm.watchIds.isEmpty);
      assert(vmIns.isDisposed);
    });

    test("batch_set_state", () async {
      final viewModel = TestStatelessViewModel();
      var c = 0;
      viewModel.listen(onChanged: () {
        c++;
        print("batch_set_state $c");
      });

      viewModel.notifyListeners();
      viewModel.notifyListeners();
      viewModel.notifyListeners();
      await Future.delayed(const Duration(seconds: 1));
      assert(c == 3);
    });

    test("changeNotifier_set_state", () async {
      late ChangeNotifierVM viewModel = ChangeNotifierVM();
      var c = 0;
      viewModel.listen(onChanged: () {
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

class ChangeNotifierVM extends ChangeNotifierViewModel {}

class ChangeNotifierVMFactory with ViewModelFactory<ChangeNotifierVM> {
  String? name;

  @override
  ChangeNotifierVM build() {
    return ChangeNotifierVM();
  }
}
