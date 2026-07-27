import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:view_model/src/view_model/binding_zone.dart';
import 'package:view_model/view_model.dart';

// A simple ViewModel for testing.
class MyViewModel with ViewModel {
  final String name;

  MyViewModel(this.name);

  ChildViewModel get childViewModel => viewModelBinding
      .read<ChildViewModel>(ViewModelSpec(builder: ChildViewModel.new));
}

class ChildViewModel with ViewModel {}

// A stateful widget that uses the ViewModel.
class MyWidget extends StatefulWidget {
  final String name;

  const MyWidget({super.key, required this.name});

  @override
  State<MyWidget> createState() => MyWidgetState();
}

class MyWidgetState extends State<MyWidget> with ViewModelStateMixin<MyWidget> {
  MyViewModel get vm => viewModelBinding.watch<MyViewModel>(
        ViewModelSpec(key: 'share', builder: () => MyViewModel(widget.name)),
      );

  ViewModelBinding get testBinding => viewModelBinding;

  @override
  Widget build(BuildContext context) {
    final viewModel = vm;
    return Text(viewModel.name);
  }
}

void main() {
  testWidgets('Dependency resolver transfer on state disposal', (tester) async {
    // Add keys to identify the widgets
    const keyA = Key('StateA');
    const keyB = Key('StateB');

    // Build two widgets sharing the same ViewModel.
    await tester.pumpWidget(
      const MaterialApp(
        home: Column(
          children: [
            MyWidget(key: keyA, name: 'StateA'),
            MyWidget(key: keyB, name: 'StateB'),
          ],
        ),
      ),
    );

    // Find the states and the ViewModel using the keys.
    final stateA = tester.state<MyWidgetState>(find.byKey(keyA));
    var stateB = tester.state<MyWidgetState>(find.byKey(keyB));
    final vm = stateA.vm;
    final initialChild = vm.childViewModel;

    // Check that stateA and stateB share the same vm instance
    expect(identical(stateA.vm, stateB.vm), isTrue);

    // Access the internal dependency handler for testing.
    final dependencyHandler = vm.refHandler;

    // Initially, the ViewModel's dependency handler should have resolvers
    // from both states.
    expect(dependencyHandler.ownerResolvers.length, 2);
    expect(
        dependencyHandler.ownerResolvers.contains(stateA.testBinding), isTrue);
    expect(
        dependencyHandler.ownerResolvers.contains(stateB.testBinding), isTrue);
    expect(
      initialChild.refHandler.dependencyBindings,
      containsAll(<ViewModelBinding>[stateA.testBinding, stateB.testBinding]),
    );

    // Dispose StateA by removing its widget.
    await tester.pumpWidget(
      const MaterialApp(
        home: Column(
          children: [
            MyWidget(key: keyB, name: 'StateB'),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    stateB = tester.state<MyWidgetState>(find.byKey(keyB));

    // After StateA is disposed, its resolver should be removed.
    expect(dependencyHandler.ownerResolvers.length, 1);
    // The remaining resolver should be from StateB.
    expect(dependencyHandler.ownerResolvers.first, stateB.testBinding);
    expect(
        dependencyHandler.ownerResolvers.contains(stateA.testBinding), isFalse);

    // Child 的 identity 属于共享 parent generation；A 退出只移除 A 的
    // propagated owner，B 仍通过 parent 保活同一个 Child。
    expect(initialChild.isDisposed, false);
    final transferredChild = stateB.vm.childViewModel;
    expect(identical(transferredChild, initialChild), true);
    expect(
      transferredChild.refHandler.dependencyBindings,
      contains(stateB.testBinding),
    );
    expect(
      transferredChild.refHandler.dependencyBindings,
      isNot(contains(stateA.testBinding)),
    );
    expect(vm.isDisposed, false);
    expect(transferredChild.isDisposed, false);
    await tester.pumpWidget(
      const MaterialApp(
        home: Column(
          children: [],
        ),
      ),
    );

    expect(vm.isDisposed, true);
    expect(transferredChild.isDisposed, true);
  });
}

// Extension to access private list of resolvers
extension on ViewModelBindingHandler {
  List<ViewModelBinding> get ownerResolvers => dependencyBindings;
}
