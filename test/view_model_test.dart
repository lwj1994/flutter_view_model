import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:view_model/view_model.dart';

import 'test_widget.dart';

void main() {
  group('view_model', () {
    late TestViewModel viewModel;
    setUp(() {
      logEnable = false;
      viewModel = TestViewModel(state: "1");
    });

    test("reducer order", () async {
      int c = 0;
      viewModel.listen((s) {
        if (c == 0) expect(s, "2");
        if (c == 1) expect(s, "3");
        if (c == 2) expect(s, "4");
        print(s);
        c++;
      });

      viewModel.setState((state) async {
        await Future.delayed(const Duration(seconds: 4));
        return "2";
      });

      viewModel.setState((state) async {
        await Future.delayed(const Duration(seconds: 2));
        return "3";
      });

      viewModel.setState((state) {
        return "4";
      });

      await Future.delayed(const Duration(seconds: 10));
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
        viewModel.setState((s) async {
          await Future.delayed(Duration(milliseconds: Random().nextInt(total)));
          return s1;
        });
        size--;
      }

      await Future.delayed(const Duration(seconds: total));
    });
  });
}
