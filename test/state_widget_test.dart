import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_widget.dart';

void main() {
  testWidgets('initState text', (tester) async {
    final testKey = GlobalKey();
    await tester.pumpWidget(MaterialApp(
        home: TestPage(
      key: testKey,
      factory: TestViewModelFactory(
        initState: "initState",
        uniquee: false,
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
      factory: TestViewModelFactory(
        initState: "initState",
        uniquee: false,
      ),
    )));
    final state = testKey.currentState as TestPageState;

    final vm1 = state.getViewModel(
        factory: TestViewModelFactory(
      initState: "initState",
      uniquee: false,
    ));

    final vm2 = state.getViewModel(
        factory: TestViewModelFactory(
      initState: "initState2",
      uniquee: false,
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
          factory: TestViewModelFactory(
            initState: "initState",
            uniquee: false,
          ),
        ),
        TestPage(
          key: testKey2,
          factory: TestViewModelFactory(
            initState: "initState2",
            uniquee: false,
          ),
        ),
      ],
    )));
    final state = testKey.currentState as TestPageState;
    final state2 = testKey2.currentState as TestPageState;

    final vm1 = state.getViewModel(
        factory: TestViewModelFactory(
      initState: "initState",
      uniquee: false,
    ));

    final vm2 = state2.getViewModel(
        factory: TestViewModelFactory(
      initState: "initState2",
      uniquee: false,
    ));
    print(vm1.state);
    print(vm2.state);
    assert(vm1 != vm2);
  });

  testWidgets('state share viewModel', (tester) async {
    final testKey = GlobalKey();
    final testKey2 = GlobalKey();
    final fc = TestViewModelFactory(
      initState: "initState",
      uniquee: true,
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
    print(vm1.state);
    print(vm2.state);
    assert(vm1 == vm2);
  });

  testWidgets('setState', (tester) async {
    final testKey = GlobalKey();
    final fc = TestViewModelFactory();
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

    state.listenViewModelState(vm, onChange: (p, n) {
      print(vm.state);
      assert(vm.state == "newState");
    });

    vm.setState((state) {
      assert(state == fc.initState);
      return "newState";
    });
  });
}
