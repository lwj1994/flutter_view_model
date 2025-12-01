import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:view_model/src/view_model/view_model.dart';
import 'package:view_model/src/view_model/widget_mixin/stateful_extension.dart';
import 'package:view_model/src/view_model/widget_mixin/stateless_extension.dart';

// 1. Define a simple ViewModel, as shown in the README.
class TestViewModel extends ViewModel {}

// 2. Define a factory for the ViewModel, implementing the `build` method.
class TestViewModelFactory with ViewModelFactory<TestViewModel> {
  @override
  TestViewModel build() => TestViewModel();
}

// 3. Define the StatefulWidget.
class TestPage extends StatefulWidget {
  const TestPage({super.key});

  @override
  State<TestPage> createState() => _TestPageState();
}

// 4. Define the State class using the ViewModelStateMixin correctly.
class _TestPageState extends State<TestPage>
    with ViewModelStateMixin<TestPage> {
  late final TestViewModel viewModel;

  @override
  void initState() {
    super.initState();
    // vef.watch will internally trigger the binder name generation.
    viewModel = vef.watch<TestViewModel>(TestViewModelFactory());
  }

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}

// 5. Define a StatelessWidget using the ViewModelStatelessMixin.
class StatelessTestPage extends StatelessWidget with ViewModelStatelessMixin {
  StatelessTestPage({super.key});

  /// Builds a simple widget and triggers ViewModel watch to
  /// ensure binder name initialization for stateless mixin.
  @override
  Widget build(BuildContext context) {
    // Watch a ViewModel to exercise attacher in stateless mixin.
    final vm = vef.watch<TestViewModel>(
      TestViewModelFactory(),
    );
    return const Placeholder();
  }
}

abstract class _BasePageState<T extends StatefulWidget> extends State<T>
    with ViewModelStateMixin {}

class _TestPageState3 extends _TestPageState2 {}

class _TestPageState2 extends _BasePageState<TestPage2> {
  late final TestViewModel viewModel;

  @override
  void initState() {
    super.initState();
    // vef.watch will internally trigger the binder name generation.
    viewModel = vef.watch<TestViewModel>(TestViewModelFactory());
  }

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}

// 6. Define a new StatefulWidget for the subclassed state.
class TestPage2 extends StatefulWidget {
  const TestPage2({super.key});

  @override
  State<TestPage2> createState() => _TestPageState3();
}

void main() {
  // Initialize the RouteObserver for the mixin to work.

  testWidgets('ViewModelStateMixin correctly generates binder name for a State',
      (tester) async {
    // Arrange: Pump our test widget.
    await tester.pumpWidget(const MaterialApp(home: TestPage()),
        duration: const Duration(seconds: 1));

    // Act: Find the state to access the result.
    final state = tester.state(find.byType(TestPage)) as _TestPageState;

    final name = state.vef.getName();
    print(name);

    // Assert: Check if the binder name correctly identifies the state class and file.
    expect(name, isNotNull);
    expect(name, contains('state_mixin_binder_test.dart'));
    expect(name, contains('_TestPageState'));
  });

  testWidgets(
      'ViewModelStateMixin correctly generates binder name for a subclassed State',
      (tester) async {
    // Arrange: Pump our test widget for the subclass.
    await tester.pumpWidget(const MaterialApp(home: TestPage2()));

    // Act: Find the state to access the result.
    final state = tester.state(find.byType(TestPage2)) as _TestPageState2;
    final name = state.vef.getName();
    print(name);
    // Assert: Check if the binder name correctly identifies the SUBCLASS.
    expect(name, isNotNull);
    expect(name, contains('state_mixin_binder_test.dart'));
    // This is the key assertion: it must identify the runtime type `_TestPageState2`.
    expect(name, contains('_TestPageState2'));
  });

  testWidgets(
      'ViewModelStatelessMixin correctly generates binder name for a StatelessWidget',
      (tester) async {
    // Arrange: Pump our stateless test widget.
    await tester.pumpWidget(MaterialApp(home: StatelessTestPage()),
        duration: const Duration(seconds: 1));

    // Act: Access the widget to read binder name.
    final widget =
        tester.widget(find.byType(StatelessTestPage)) as StatelessTestPage;
    final name = widget.getViewModelBinderName();
    print(name);

    // Assert: Check file and runtime type markers.
    expect(name, isNotNull);
    expect(name, contains('state_mixin_binder_test.dart'));
    expect(name, contains('StatelessTestPage'));
  });
}
