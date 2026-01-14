import 'package:flutter_test/flutter_test.dart';
import 'package:view_model/view_model.dart';

import 'test_widget.dart';

void main() {
  group('view_model state', () {
    late TestViewModel viewModel;

    setUpAll(() {
      ViewModel.initialize(config: ViewModelConfig(isLoggingEnabled: true));
    });

    setUp(() {
      viewModel = TestViewModel(state: "0");
    });

    test("should correctly trigger listeners on batch state updates", () async {
      const total = 100;
      int listenStateCount = 0;

      viewModel.listenState(onChanged: (p, s) {
        listenStateCount++;
        expect(s, listenStateCount.toString());
        expect(p, (listenStateCount - 1).toString());
      });

      int listenCallbackCount = 0;
      viewModel.listen(onChanged: () {
        listenCallbackCount++;
      });

      for (int i = 1; i <= total; i++) {
        viewModel.setState(i.toString());
      }

      while (listenStateCount < total) {
        await Future.delayed(Duration.zero);
      }

      expect(listenCallbackCount, total);
      expect(listenStateCount, total);
    });

    test("should correctly update state on notifyListeners", () async {
      int completedCount = 0;

      viewModel.listen(onChanged: () {
        expect(viewModel.name, "a");
        completedCount += 1;
      });

      viewModel.name = "a";
      viewModel.notifyListeners();
      while (completedCount < 1) {
        await Future.delayed(Duration.zero);
      }
    });
  });

  group('state_view_model extras', () {
    test('listenState unsubscription works', () {
      final vm = TestViewModel(state: "0");
      final dispose = vm.listenState(onChanged: (prev, curr) {});
      dispose();
    });

    test('notifyListeners after dispose is ignored', () {
      final vm = TestViewModel(state: "0");
      vm.onDispose(const InstanceArg());
      vm.notifyListeners();
    });

    test('setState after dispose is ignored', () {
      final vm = TestViewModel(state: "0");
      vm.onDispose(const InstanceArg());
      vm.setState("1");
    });
  });
}
