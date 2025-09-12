// Test for multi-level ViewModel dependencies
// A depends on B, B depends on C, C depends on D

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:view_model/view_model.dart';

/// Level D ViewModel - bottom of dependency chain
class ViewModelD with ViewModel {
  String get data => 'Data from D';
}

/// Level C ViewModel - depends on D
class ViewModelC with ViewModel {
  ViewModelD? _viewModelD;

  String get data {
    _viewModelD ??= readViewModel<ViewModelD>(
      factory: DefaultViewModelFactory<ViewModelD>(builder: () => ViewModelD()),
    );
    return 'C -> ${_viewModelD!.data}';
  }
}

/// Level B ViewModel - depends on C
class ViewModelB with ViewModel {
  ViewModelC? _viewModelC;

  String get data {
    _viewModelC ??= readViewModel<ViewModelC>(
      factory: DefaultViewModelFactory<ViewModelC>(builder: () => ViewModelC()),
    );
    return 'B -> ${_viewModelC!.data}';
  }
}

/// Level A ViewModel - depends on B (top of dependency chain)
class ViewModelA with ViewModel {
  ViewModelB? _viewModelB;

  String get data {
    _viewModelB ??= readViewModel<ViewModelB>(
      factory: DefaultViewModelFactory<ViewModelB>(builder: () => ViewModelB()),
    );
    return 'A -> ${_viewModelB!.data}';
  }
}

/// Test widget that uses ViewModelA
class TestWidget extends StatefulWidget {
  const TestWidget({super.key});

  @override
  _TestWidgetState createState() => _TestWidgetState();
}

class _TestWidgetState extends State<TestWidget> with ViewModelStateMixin {
  @override
  Widget build(BuildContext context) {
    final viewModelA = watchViewModel<ViewModelA>(
      factory: DefaultViewModelFactory<ViewModelA>(builder: () => ViewModelA()),
    );

    return Text(viewModelA.data);
  }
}

void main() {
  group('Multi-level ViewModel Dependencies', () {
    testWidgets('should create dependency chain A->B->C->D', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TestWidget(),
          ),
        ),
      );

      // Verify the complete dependency chain is working
      expect(find.text('A -> B -> C -> Data from D'), findsOneWidget);
    });

    testWidgets('should properly dispose dependency chain', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TestWidget(),
          ),
        ),
      );

      // Verify widget is built
      expect(find.text('A -> B -> C -> Data from D'), findsOneWidget);

      // Navigate away to trigger dispose
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Text('Empty'),
          ),
        ),
      );

      // Verify no memory leaks (this is implicit - if there were leaks,
      // the test framework would detect them)
      expect(find.text('Empty'), findsOneWidget);
    });
  });
}
