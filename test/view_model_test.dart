import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:view_model/view_model.dart';

import 'test_widget.dart';

void main() {
  group('view_model state', () {
    late TestViewModel viewModel;
    setUp(() {
      ViewModel.logEnable = false;
      viewModel = TestViewModel(state: "1");
    });

    test("batch_set_state", () async {
      const total = 100;

      viewModel.listen((s) {
        print("${viewModel.previousState} -> $s");

        if (viewModel.previousState != viewModel.initState) {
          expect(
            s,
            (int.parse(viewModel.previousState ?? "$total") - 1).toString(),
          );
        }
      });

      int size = total;

      while (size > 0) {
        final s1 = size.toString();
        await viewModel.setState((state) async {
          await Future.delayed(Duration(milliseconds: Random().nextInt(total)));
          return s1;
        });
        size--;
      }
    });
  });
}
