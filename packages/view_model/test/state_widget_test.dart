import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:view_model/view_model.dart';

import 'test_widget.dart';

void main() {
  group('ViewModel Widget Tests', () {
    setUp(() {
      ViewModel.initialize(config: ViewModelConfig(logEnable: true));
    });

    testWidgets('should initialize with correct state', (tester) async {
      final testKey = GlobalKey();
      await tester.pumpWidget(MaterialApp(
          home: TestPage(
        key: testKey,
        factory: const TestViewModelFactory(
          initState: "initState",
          isSingleton: false,
        ),
      )));

      expect(find.text('initState'), findsOneWidget);

      (testKey.currentState as TestPageState)
          .readViewModel<TestViewModel>()
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
          isSingleton: false,
        ),
      )));

      final state = testKey.currentState as TestPageState;
      final vm1 = state.watchViewModel(
          factory: const TestViewModelFactory(
        initState: "initState",
        isSingleton: false,
      ));

      final vm2 = state.watchViewModel(
          factory: const TestViewModelFactory(
        initState: "initState2",
        isSingleton: false,
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
              isSingleton: false,
            ),
          ),
          TestPage(
            key: testKey2,
            factory: const TestViewModelFactory(
              initState: "initState2",
              isSingleton: false,
            ),
          ),
        ],
      )));

      final state = testKey.currentState as TestPageState;
      final state2 = testKey2.currentState as TestPageState;

      final vm1 = state.watchViewModel(
          factory: const TestViewModelFactory(
        initState: "initState",
        isSingleton: false,
      ));

      final vm2 = state2.watchViewModel(
          factory: const TestViewModelFactory(
        initState: "initState2",
        isSingleton: false,
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
        () => state.readViewModel<TestViewModel>(key: "non_existent"),
        throwsA(isA<StateError>()),
      );
    });

    testWidgets('state share exiting viewModel by tag', (tester) async {
      final testKey = GlobalKey();
      final testKey2 = GlobalKey();
      const fc = TestViewModelFactory(initState: "initState", tag: "1");
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

      final vm1 = state.readViewModel<TestViewModel>(tag: "1");
      final vm2 = state2.readViewModel<TestViewModel>();
      final vm3 = ViewModel.read<TestViewModel>();

      print(vm1.state);
      print(vm2.state);
      assert(vm1.state == "initState2");
      assert(vm2.state == "initState2");
      assert(vm1 == vm2);
      assert(vm1 == vm3);
    });

    testWidgets('state share exiting viewModel', (tester) async {
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

      final vm1 = state.readViewModel<TestViewModel>();
      final vm2 = state2.readViewModel<TestViewModel>();
      final vm3 = ViewModel.read<TestViewModel>();

      print(vm1.state);
      print(vm2.state);
      assert(vm1.state == "initState2");
      assert(vm2.state == "initState2");
      assert(vm1 == vm2);
      assert(vm1 == vm3);
    });

    testWidgets('state share singleton viewModel', (tester) async {
      final testKey = GlobalKey();
      final testKey2 = GlobalKey();
      const fc = TestViewModelFactory(
        initState: "initState",
        isSingleton: true,
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

      final vm1 = state.readViewModel(factory: fc);

      final vm2 = state2.readViewModel(factory: fc);
      final vm3 = state2.readViewModel<TestViewModel>();
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
      final vm = state.readViewModel(
        factory: fc,
      );

      final vm2 = state.readViewModel<TestViewModel>(key: "key");

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
      final vm = state.readViewModel(
        factory: fc,
      );

      final vm2 = state.readViewModel<TestViewModel>();

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
      final vm = state.readViewModel(
        factory: fc,
      );

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
      final vm = state.readViewModel(factory: fc);

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
      final vm = state.readViewModel(factory: fc);

      state.recycleViewModel(vm);
      final vm2 = state.readViewModel(factory: fc);
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
      final vm = state.readViewModel(
        factory: fc,
      );

      final vm2 = state.readViewModel<TestViewModel>();
      assert(vm == vm2);
      final TestViewModel vm3 =
          state.readViewModel<TestViewModel>(key: "2", factory: fc);
      assert(vm == vm3);
    });
  });
}
