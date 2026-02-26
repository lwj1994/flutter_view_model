import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:view_model/src/view_model/state_store.dart';
import 'package:view_model/view_model.dart';

import 'test_widget.dart';

void main() {
  group('ViewModel Widget Tests', () {
    setUp(() {
      ViewModel.initialize(config: ViewModelConfig(isLoggingEnabled: true));
    });

    testWidgets('should initialize with correct state', (tester) async {
      final testKey = GlobalKey();
      await tester.pumpWidget(MaterialApp(
          home: TestPage(
        key: testKey,
        factory: const TestViewModelFactory(
          initState: "initState",
        ),
      )));

      expect(find.text('initState'), findsOneWidget);

      (testKey.currentState as TestPageState)
          .viewModelBinding
          .readCached<TestViewModel>()
          .setState("hi");
      await tester.pumpAndSettle();
      expect(find.text('hi'), findsOneWidget);
    });

    testWidgets('should share ViewModel instance when using same factory',
        (tester) async {
      final testKey = GlobalKey();
      await tester.pumpWidget(MaterialApp(
          home: TestPage(
        key: testKey,
        factory: const TestViewModelFactory(
          initState: "initState",
        ),
      )));

      final state = testKey.currentState as TestPageState;
      final vm1 = state.viewModelBinding
          .watch<TestViewModel>(const TestViewModelFactory(
        initState: "initState",
      ));

      final vm2 = state.viewModelBinding
          .watch<TestViewModel>(const TestViewModelFactory(
        initState: "initState2",
      ));

      expect(vm2.state, "initState");
      expect(vm1, equals(vm2));
      expect(vm1.isDisposed, false);
      expect(vm2.isDisposed, false);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();

      expect(vm1.isDisposed, true);
      expect(vm2.isDisposed, true);
    });

    testWidgets('should create separate ViewModels for different pages',
        (tester) async {
      final testKey = GlobalKey();
      final testKey2 = GlobalKey();
      await tester.pumpWidget(MaterialApp(
          home: Column(
        children: [
          TestPage(
            key: testKey,
            factory: const TestViewModelFactory(
              initState: "initState",
            ),
          ),
          TestPage(
            key: testKey2,
            factory: const TestViewModelFactory(
              initState: "initState2",
            ),
          ),
        ],
      )));

      final state = testKey.currentState as TestPageState;
      final state2 = testKey2.currentState as TestPageState;

      final vm1 = state.viewModelBinding
          .watch<TestViewModel>(const TestViewModelFactory(
        initState: "initState",
      ));

      final vm2 = state2.viewModelBinding
          .watch<TestViewModel>(const TestViewModelFactory(
        initState: "initState2",
      ));

      expect(vm1, isNot(equals(vm2)));
      expect(vm1.state, "initState");
      expect(vm2.state, "initState2");
    });

    testWidgets('should handle ViewModel errors appropriately', (tester) async {
      final testKey = GlobalKey();
      const fc = TestViewModelFactory();
      await tester.pumpWidget(MaterialApp(
          home: Column(
        children: [
          TestPage(
            key: testKey,
            factory: fc,
          ),
        ],
      )));

      final state = testKey.currentState as TestPageState;

      expect(
        () => state.viewModelBinding
            .readCached<TestViewModel>(key: "non_existent"),
        throwsA(isA<ViewModelError>()),
      );
    });

    testWidgets('state share existing viewModel by tag', (tester) async {
      final testKey = GlobalKey();
      final testKey2 = GlobalKey();
      const fc = TestViewModelFactory(initState: "initState", tagV: "1");
      await tester.pumpWidget(MaterialApp(
          home: Column(
        children: [
          TestPage(
            key: testKey,
            factory: fc.copyWith(
              initState: "initState1",
            ),
          ),
          TestPage(
            key: testKey2,
            factory: fc.copyWith(
              initState: "initState2",
            ),
          ),
        ],
      )));
      final state = testKey.currentState as TestPageState;
      final state2 = testKey2.currentState as TestPageState;

      final vm1 = state.viewModelBinding.readCached<TestViewModel>(tag: "1");
      final vm2 = state2.viewModelBinding.readCached<TestViewModel>();
      final vm3 = ViewModel.readCached<TestViewModel>();

      print(vm1.state);
      print(vm2.state);
      assert(vm1.state == "initState2");
      assert(vm2.state == "initState2");
      assert(vm1 == vm2);
      assert(vm1 == vm3);
    });

    testWidgets('state share existing viewModel', (tester) async {
      final testKey = GlobalKey();
      final testKey2 = GlobalKey();
      const fc = TestViewModelFactory(
        initState: "initState",
      );
      await tester.pumpWidget(MaterialApp(
          home: Column(
        children: [
          TestPage(
            key: testKey,
            factory: fc.copyWith(
              initState: "initState1",
            ),
          ),
          TestPage(
            key: testKey2,
            factory: fc.copyWith(
              initState: "initState2",
            ),
          ),
        ],
      )));
      final state = testKey.currentState as TestPageState;
      final state2 = testKey2.currentState as TestPageState;

      final vm1 = state.viewModelBinding.readCached<TestViewModel>();
      final vm2 = state2.viewModelBinding.readCached<TestViewModel>();
      final vm3 = ViewModel.readCached<TestViewModel>();

      print(vm1.state);
      print(vm2.state);
      assert(vm1.state == "initState2");
      assert(vm2.state == "initState2");
      assert(vm1 == vm2);
      assert(vm1 == vm3);
    });

    testWidgets('state share shared key viewModel', (tester) async {
      final testKey = GlobalKey();
      final testKey2 = GlobalKey();
      const fc = TestViewModelFactory(
        initState: "initState",
        keyV: "shared_key",
      );
      await tester.pumpWidget(MaterialApp(
          home: Column(
        children: [
          TestPage(
            key: testKey,
            factory: fc,
          ),
          TestPage(
            key: testKey2,
            factory: fc,
          ),
        ],
      )));
      final state = testKey.currentState as TestPageState;
      final state2 = testKey2.currentState as TestPageState;

      final vm1 = state.viewModelBinding.read(fc);

      final vm2 = state2.viewModelBinding.read(fc);
      final vm3 = state2.viewModelBinding.readCached<TestViewModel>();
      print(vm1.state);
      print(vm2.state);
      print(vm3.state);
      assert(vm1 == vm2);
      assert(vm1 == vm3);
    });

    testWidgets('requireExistingViewModel with key', (tester) async {
      final testKey = GlobalKey();
      const fc = TestViewModelFactory(keyV: "key");
      await tester.pumpWidget(MaterialApp(
          home: Column(
        children: [
          TestPage(
            key: testKey,
            factory: fc,
          ),
        ],
      )));
      final state = testKey.currentState as TestPageState;
      final vm = state.viewModelBinding.read(
        fc,
      );

      final vm2 = state.viewModelBinding.readCached<TestViewModel>(key: "key");

      assert(vm == vm2);
      vm2.setState("2");
      assert(vm.state == "2");
    });

    testWidgets('requireExistingViewModel', (tester) async {
      final testKey = GlobalKey();
      const fc = TestViewModelFactory();
      print("key = ${fc.key()}");
      await tester.pumpWidget(MaterialApp(
          home: Column(
        children: [
          TestPage(
            key: testKey,
            factory: fc,
          ),
        ],
      )));
      final state = testKey.currentState as TestPageState;
      final vm = state.viewModelBinding.read(fc);

      final vm2 = state.viewModelBinding.readCached<TestViewModel>();

      assert(vm == vm2);
      vm2.setState("2");
      assert(vm.state == "2");
    });

    testWidgets('getViewModel without listen', (tester) async {
      final testKey = GlobalKey();
      const fc = TestViewModelFactory();
      await tester.pumpWidget(MaterialApp(
          home: Column(
        children: [
          TestPage(
            key: testKey,
            factory: fc,
          ),
        ],
      )));
      final state = testKey.currentState as TestPageState;
      final vm = state.viewModelBinding.read(fc);

      var c = 0;
      vm.listenState(onChanged: (p, n) {
        print(n);
        if (c == 0) assert(n == "2");
        if (c == 1) assert(n == "3");
        c++;
      });

      vm.setState("2");

      final stateText = find.text(vm.initState);
      expect(stateText, findsOneWidget);
    });

    testWidgets('setState', (tester) async {
      final testKey = GlobalKey();
      const fc = TestViewModelFactory();
      await tester.pumpWidget(MaterialApp(
          home: Column(
        children: [
          TestPage(
            key: testKey,
            factory: fc,
          ),
        ],
      )));
      final state = testKey.currentState as TestPageState;
      final vm = state.viewModelBinding.read(fc);

      var c = 0;
      vm.listenState(onChanged: (p, n) {
        print(n);
        if (c == 0) assert(n == "2");
        if (c == 1) assert(n == "3");
        c++;
      });

      vm.setState("2");
      assert(vm.state == "2");
      vm.setState("3");
      assert(vm.state == "3");
    });

    testWidgets('refresh viewModel', (tester) async {
      final testKey = GlobalKey();
      const fc = TestViewModelFactory();
      await tester.pumpWidget(MaterialApp(
          home: Column(
        children: [
          TestPage(
            key: testKey,
            factory: fc,
          ),
        ],
      )));
      final state = testKey.currentState as TestPageState;
      final vm = state.viewModelBinding.read(fc);

      state.viewModelBinding.recycle(vm);
      final vm2 = state.viewModelBinding.read(fc);
      assert(vm != vm2);
    });

    testWidgets('read ViewModel error', (tester) async {
      final testKey = GlobalKey();
      const fc = TestViewModelFactory();
      await tester.pumpWidget(MaterialApp(
          home: Column(
        children: [
          TestPage(
            key: testKey,
            factory: fc,
          ),
        ],
      )));
      final state = testKey.currentState as TestPageState;
      final vm = state.viewModelBinding.read(
        fc,
      );

      final vm2 = state.viewModelBinding.readCached<TestViewModel>();
      assert(vm == vm2);
      final TestViewModel vm3 = state.viewModelBinding.read<TestViewModel>(fc);
      assert(vm == vm3);
    });
  });
}
