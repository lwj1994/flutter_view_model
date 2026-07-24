import 'package:flutter_test/flutter_test.dart';
import 'package:view_model/view_model.dart';

void main() {
  group('ViewModelConfig', () {
    test('equals defaults to null', () {
      expect(ViewModelConfig().equals, isNull);
    });

    test('custom equals works', () {
      ViewModel.reset();
      ViewModel.initialize(
        config: ViewModelConfig(
          equals: (prev, curr) {
            // Always true means no updates
            return true;
          },
        ),
      );
      final owner = _TestConfigViewModelOwner();
      addTearDown(() {
        owner.dispose();
        ViewModel.reset();
      });

      final vm = owner.viewModel;
      // Initial state
      expect(vm.state, 0);

      // Update
      vm.increment();
      // Since equals returns true, _update should return early.
      expect(vm.state, 0);
    });
  });
}

final _testConfigViewModelSpec = ViewModelSpec<TestConfigViewModel>(
  builder: TestConfigViewModel.new,
);

class _TestConfigViewModelOwner with ViewModelBinding {
  TestConfigViewModel get viewModel => read(_testConfigViewModelSpec);
}

class TestConfigViewModel extends StateViewModel<int> {
  TestConfigViewModel() : super(state: 0);

  void increment() {
    setState(state + 1);
  }
}
