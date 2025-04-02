import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:view_model/view_model.dart';

import 'test_widget.dart';

void main() {
  group('view_model reducer', () {
    late TestViewModel viewModel;
    setUp(() {
      ViewModel.logEnable = false;
      viewModel = TestViewModel(state: "1");
    });

    test("async_state tag", () async {
      int c = 0;
      viewModel.listenAsync((s) {
        print(s.toString());
        if (c == 0) assert(s is AsyncLoading && s.tag == "tag");
        if (c == 1) assert(s is AsyncSuccess && s.tag == "tag");
        c++;
      });

      viewModel.setState((s) async {
        await Future.delayed(const Duration(milliseconds: 2000));
        return AsyncSuccess(state: "2");
      }, tag: "tag");

      await Future.delayed(const Duration(seconds: 2));
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
        return AsyncSuccess(state: "2");
      });

      viewModel.setState((state) async {
        await Future.delayed(const Duration(seconds: 2));
        return AsyncSuccess(state: "3");
      });

      viewModel.setState((state) {
        return AsyncSuccess(state: "4");
      });

      await Future.delayed(const Duration(seconds: 10));
    });

    test("set_state success", () async {
      int c = 0;
      viewModel.listenAsync((s) {
        print(s.toString());
        if (c == 0) assert(s is AsyncLoading);
        if (c == 1) assert(s is AsyncSuccess);
        c++;
      });

      viewModel.setState((s) async {
        await Future.delayed(const Duration(milliseconds: 2000));
        return AsyncSuccess(state: "2");
      });

      await Future.delayed(const Duration(seconds: 2));
    });

    test("set_state error", () async {
      int c = 0;
      viewModel.listenAsync((s) {
        print(s.toString());
        if (c == 0) assert(s is AsyncLoading);
        if (c == 1) assert(s is AsyncError);
        c++;
      });

      viewModel.setState((s) async {
        await Future.delayed(Duration(milliseconds: Random().nextInt(1000)));
        throw Exception("test error");
      });

      await Future.delayed(const Duration(seconds: 2));
    });

    test("batch_set_state", () async {
      const total = 100;
      viewModel.listenAsync((s) {
        print(s.toString());
      });

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
          return AsyncSuccess(state: s1);
        });
        size--;
      }

      await Future.delayed(const Duration(seconds: total));
    });

    test("idleState", () async {
      viewModel.listenAsync((s) {
        print(s.toString());
      });

      viewModel.setState((s) async {
        return AsyncSuccess(state: "2");
      });
      // normal state
      assert(viewModel.state != "2");

      final idleState = await viewModel.successState;
      assert(idleState == "2");

      viewModel.setState((s) async {
        return AsyncSuccess(state: "3");
      });
      viewModel.setState((s) async {
        return AsyncSuccess(state: "4");
      });

      assert(viewModel.state == "2");
      assert(await viewModel.successState == "4");

      viewModel.setState((s) async {
        await Future.delayed(Duration(seconds: 3));
        return AsyncSuccess(state: "5");
      });

      assert(viewModel.state == "4");
      assert(await viewModel.successState == "5");
    });
  });

  group('view_model setter state', () {
    late TestViewModel viewModel;
    setUp(() {
      ViewModel.logEnable = false;
      viewModel = TestViewModel(state: "1");
    });

    test("set_state success", () async {
      int c = 0;
      viewModel.listenAsync((s) {
        print(s.toString());
        if (c == 0) assert(s is AsyncSuccess);
        c++;
      });

      viewModel.state = "2";

      await Future.delayed(const Duration(seconds: 2));
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
        await Future.delayed(Duration(milliseconds: Random().nextInt(total)));
        viewModel.state = s1;
        size--;
      }
    });
  });
}
