import 'package:flutter_test/flutter_test.dart';
import 'package:view_model/view_model.dart';

import 'test_widget.dart';

void main() {
  group('view_model state', () {
    late TestViewModel viewModel;

    setUp(() {
      ViewModel.initConfig(ViewModelConfig(logEnable: true));
      viewModel = TestViewModel(state: "0");
    });

    test("should correctly trigger listeners on batch state updates", () async {
      const total = 100;
      int listenStateCount = 0;

      viewModel.listenState(onChanged: (p, s) {
        listenStateCount++;
        expect(s, listenStateCount);
        expect(p, listenStateCount - 1);
      });

      int listenCallbackCount = 0;
      viewModel.listen(onChanged: () {
        listenCallbackCount++;
        expect(viewModel.state, listenCallbackCount);
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
}
