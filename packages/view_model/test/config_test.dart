import 'package:flutter_test/flutter_test.dart';
import 'package:view_model/view_model.dart';

void main() {
  group('ViewModelConfig', () {
    test('custom equals works', () {
      // Initialize with custom config
      ViewModel.initialize(
        config: ViewModelConfig(
          equals: (prev, curr) {
            // Always true means no updates
            return true;
          },
        ),
      );

      final vm = TestConfigViewModel();
      // Initial state
      expect(vm.state, 0);

      // Update
      vm.increment();
      // Since equals returns true, _update should return early.
      expect(vm.state, 0);

      // Note: We cannot easily reset ViewModel.config in the same process
      // because initialize() guards against re-initialization.
      // So we can't test the "reset to default" behavior in the same test run
      // if we already initialized it.
      // But we verified the custom config works.
    });
  });
}

class TestConfigViewModel extends StateViewModel<int> {
  TestConfigViewModel() : super(state: 0);

  void increment() {
    setState(state + 1);
  }
}
