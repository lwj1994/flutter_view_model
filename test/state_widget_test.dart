import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:view_model/view_model.dart';

import 'test_widget.dart';

void main() {
  setUp(() {
    ViewModel.initConfig(ViewModelConfig(logEnable: true));
  });
  testWidgets('initState text', (tester) async {
    final testKey = GlobalKey();
    await tester.pumpWidget(MaterialApp(
        home: TestPage(
      key: testKey,
      factory: const TestViewModelFactory(
        initState: "initState",
        isSingleton: false,
      ),
    )));

    // Create the Finders.
    final stateText = find.text('initState');
    expect(stateText, findsOneWidget);
  });

  testWidgets('state viewModel', (tester) async {
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

    final vm1 = state.getViewModel(
        factory: const TestViewModelFactory(
      initState: "initState",
      isSingleton: false,
    ));

    final vm2 = state.getViewModel(
        factory: const TestViewModelFactory(
      initState: "initState2",
      isSingleton: false,
    ));

    assert(vm2.state == "initState");
    // same state will get same ViewModel
    assert(vm1 == vm2);
    expect(vm1.isDisposed, false);
    expect(vm2.isDisposed, false);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();

    expect(vm1.isDisposed, true);
    expect(vm2.isDisposed, true);
  });

  testWidgets('state dont share viewModel', (tester) async {
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

    final vm1 = state.getViewModel(
        factory: const TestViewModelFactory(
      initState: "initState",
      isSingleton: false,
    ));

    final vm2 = state2.getViewModel(
        factory: const TestViewModelFactory(
      initState: "initState2",
      isSingleton: false,
    ));
    print(vm1.state);
    print(vm2.state);
    assert(vm1 != vm2);
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

    final vm1 = state.requireExistingViewModel<TestViewModel>();
    final vm2 = state2.requireExistingViewModel<TestViewModel>();
    print(vm1.state);
    print(vm2.state);
    assert(vm1.state == "initState2");
    assert(vm2.state == "initState2");
    assert(vm1 == vm2);
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

    final vm1 = state.getViewModel(factory: fc);

    final vm2 = state2.getViewModel(factory: fc);
    final vm3 = state2.requireExistingViewModel<TestViewModel>();
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
    final vm = state.getViewModel(
      factory: fc,
      listen: false,
    );

    final vm2 = state.requireExistingViewModel<TestViewModel>(key: "key");

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
    final vm = state.getViewModel(
      factory: fc,
      listen: false,
    );

    final vm2 = state.requireExistingViewModel<TestViewModel>();

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
    final vm = state.getViewModel(
      factory: fc,
      listen: false,
    );

    var c = 0;
    vm.listen(onChanged: (p, n) {
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
    final vm = state.getViewModel(factory: fc);

    var c = 0;
    vm.listen(onChanged: (p, n) {
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
    final vm = state.getViewModel(factory: fc);

    state.refreshViewModel(vm);
    final vm2 = state.getViewModel(factory: fc);

    assert(vm != vm2);
  });
}
