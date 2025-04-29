import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:view_model/view_model.dart';

import 'test_widget.dart';

void main() {
  group('view_model state', () {
    late TestViewModel viewModel;
    setUp(() {
      ViewModel.initConfig(ViewModelConfig(logEnable: true));
      viewModel = TestViewModel(state: "1");
    });

    test("batch_set_state block", () async {
      const total = 100;

      viewModel.listen(onChanged: (p, s) {
        print("batch_set_state $p -> $s");

        if (p != viewModel.initState) {
          expect(
            s,
            (int.parse(p ?? "$total") - 1).toString(),
          );
        }
      });

      int size = total;

      while (size > 0) {
        final s1 = size.toString();
        viewModel.setState(s1);
        size--;
      }

      await Future.delayed(const Duration(seconds: 3));
    });

    test("set_state block", () async {
      int c = 0;
      viewModel.listen(onChanged: (p, s) {
        print("$p -> $s");
        if (c == 0) {
          expect(p, "1");
          expect(s, "2");
        }

        if (c == 1) {
          expect(p, "2");
          expect(s, "3");
        }

        if (c == 2) {
          expect(p, "3");
          expect(s, "4");
        }

        c++;
      });

      viewModel.setState("2");
      expect(viewModel.state, '2');
      viewModel.setState("3");
      expect(viewModel.state, '3');

      while (Random().nextInt(100) != 29) {}
      viewModel.setState("4");
      expect(viewModel.state, '4');
    });
  });
}
