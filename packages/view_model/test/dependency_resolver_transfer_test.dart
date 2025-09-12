import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:view_model/view_model.dart';
import 'package:view_model/src/view_model/dependency_handler.dart';

// A simple ViewModel for testing.
class MyViewModel with ViewModel {
  final String name;
  MyViewModel(this.name) {
    childViewModel1 = readViewModel<ChildViewModel1>(
        factory: DefaultViewModelFactory(builder: () => ChildViewModel1()));
  }
  late ChildViewModel2 childViewModel2;
  late ChildViewModel1 childViewModel1;

  void doSome() {
    childViewModel2 = readViewModel<ChildViewModel2>(
        factory: DefaultViewModelFactory(builder: () => ChildViewModel2()));
  }
}

class ChildViewModel1 with ViewModel {}

class ChildViewModel2 with ViewModel {}

// A stateful widget that uses the ViewModel.
class MyWidget extends StatefulWidget {
  final String name;
  const MyWidget({super.key, required this.name});

  @override
  State<MyWidget> createState() => MyWidgetState();
}

class MyWidgetState extends State<MyWidget> with ViewModelStateMixin<MyWidget> {
  late MyViewModel vm;

  @override
  void initState() {
    super.initState();
    // Use a key to ensure the same ViewModel instance is shared.
    vm = watchViewModel<MyViewModel>(
      factory: DefaultViewModelFactory(
          key: "share", builder: () => MyViewModel(widget.name)),
    );
  }

  void doSome() {
    vm.doSome();
  }

  @override
  Widget build(BuildContext context) {
    return Text(vm.name);
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

    // Check that stateA and stateB share the same vm instance
    expect(identical(stateA.vm, stateB.vm), isTrue);

    // Access the internal dependency handler for testing.
    final dependencyHandler = vm.dependencyHandler;

    // Initially, the ViewModel's dependency handler should have resolvers from both states.
    expect(dependencyHandler.ownerResolvers.length, 2);
    expect(dependencyHandler.ownerResolvers.contains(stateA.resolver), isTrue);
    expect(dependencyHandler.ownerResolvers.contains(stateB.resolver), isTrue);

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
    expect(dependencyHandler.ownerResolvers.first, stateB.resolver);
    expect(dependencyHandler.ownerResolvers.contains(stateA.resolver), isFalse);

    expect(() => stateB.vm.childViewModel2, throwsA(isA<Error>()));

    stateB.vm.doSome();

    expect(
        stateB.vm.childViewModel2.dependencyHandler.dependencyResolvers
                .length ==
            1,
        true);
    expect(
        stateB.vm.childViewModel2.dependencyHandler.dependencyResolvers
            .contains(stateB.resolver),
        isTrue);

    expect(stateB.vm.isDisposed, false);
    expect(stateB.vm.childViewModel2.isDisposed, false);
    expect(stateB.vm.childViewModel1.isDisposed, true);
    await tester.pumpWidget(
      const MaterialApp(
        home: Column(
          children: [],
        ),
      ),
    );

    expect(stateB.vm.isDisposed, true);
    expect(stateB.vm.childViewModel2.isDisposed, true);
    expect(stateB.vm.childViewModel1.isDisposed, true);
  });
}

extension on ViewModelStateMixin {
  DependencyResolver get resolver => onChildDependencyResolver;
}

// Extension to access private list of resolvers
extension on DependencyHandler {
  List<DependencyResolver> get ownerResolvers => dependencyResolvers;
}
