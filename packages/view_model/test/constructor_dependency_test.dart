import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:view_model/view_model.dart';

// A ViewModel that depends on another ViewModel.
class ViewModelA extends ViewModel {
  late final ViewModelB viewModelB;

  ViewModelA() {
    // The vef.read<ViewModelB>() call happens here, in the constructor body.
    // This is the core scenario we are testing.
    viewModelB = vef.readCached<ViewModelB>();
  }
}

// A simple dependency ViewModel.
class ViewModelB extends ViewModel {}

// A parent widget that "provides" ViewModelB.
class ParentProviderWidget extends StatefulWidget {
  final Widget child;
  const ParentProviderWidget({super.key, required this.child});

  @override
  State<ParentProviderWidget> createState() => ParentProviderWidgetState();
}

class ParentProviderWidgetState extends State<ParentProviderWidget>
    with ViewModelStateMixin<ParentProviderWidget> {
  // This will create and hold the instance of ViewModelB.
  late final ViewModelB providedViewModelB;

  @override
  void initState() {
    super.initState();
    providedViewModelB = vef.watch<ViewModelB>(
      ViewModelProvider<ViewModelB>(
        builder: () => ViewModelB(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

// A child widget that creates ViewModelA, which in turn depends on ViewModelB.
class ChildConsumerWidget extends StatefulWidget {
  const ChildConsumerWidget({super.key});

  @override
  State<ChildConsumerWidget> createState() => ChildConsumerWidgetState();
}

class ChildConsumerWidgetState extends State<ChildConsumerWidget>
    with ViewModelStateMixin<ChildConsumerWidget> {
  // This will create ViewModelA. Its constructor will attempt to read ViewModelB.
  late final ViewModelA consumingViewModelA;

  @override
  void initState() {
    super.initState();
    consumingViewModelA = vef.watch<ViewModelA>(
      ViewModelProvider<ViewModelA>(
        builder: () => ViewModelA(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Text('Child Widget');
  }
}

void main() {
  group('ViewModel Constructor Dependency', () {
    testWidgets(
        'should correctly resolve dependency from parent when vef.read is called in constructor',
        (WidgetTester tester) async {
      final parentKey = GlobalKey<ParentProviderWidgetState>();
      final childKey = GlobalKey<ChildConsumerWidgetState>();

      await tester.pumpWidget(
        MaterialApp(
          home: ParentProviderWidget(
            key: parentKey,
            child: ChildConsumerWidget(key: childKey),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final parentState = parentKey.currentState;
      final childState = childKey.currentState;

      // --- The Assertion ---
      // We verify that the viewModelB instance inside viewModelA (created by the child)
      // is the exact same instance that was provided by the parent widget.
      // This proves that the dependency was correctly resolved via the context
      // (thanks to the Zone mechanism) and not from a wrong global cache or fallback.
      expect(parentState, isNotNull);
      expect(childState, isNotNull);
      expect(childState!.consumingViewModelA, isNotNull);
      expect(childState.consumingViewModelA.viewModelB, isNotNull);
      expect(childState.consumingViewModelA.viewModelB,
          same(parentState!.providedViewModelB));
    });
  });
}
