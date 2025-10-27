import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:view_model/view_model.dart';

/// Verify that ViewModels with different generic parameters use separate stores
/// and are never mixed. We define a generic `GenericVM<T>`, create
/// `GenericVM<String>` and `GenericVM<dynamic>` instances, and read them from
/// cache by type to ensure isolation.
void main() {
  group('Generic type store isolation', () {
    setUp(() {
      ViewModel.initialize(config: ViewModelConfig(logEnable: true));
    });

    assert(GenericVM<String> != GenericVM<dynamic>);
    assert(GenericVM<String> != GenericVM<String?>);
    testWidgets(
        'Cached reads for GenericVM<String> and GenericVM<dynamic> are isolated',
        (tester) async {
      // Define two factories to create ViewModels with different generic types
      final stringFactory = DefaultViewModelFactory<GenericVM<String>>(
        builder: () => GenericVM<String>(state: 'string_state'),
      );

      final dynamicFactory = DefaultViewModelFactory<GenericVM<dynamic>>(
        builder: () => GenericVM<dynamic>(state: 123),
      );

      final k1 = GlobalKey();
      final k2 = GlobalKey();

      await tester.pumpWidget(MaterialApp(
        home: Column(
          children: [
            GenericPage<String>(key: k1, factory: stringFactory),
            GenericPage<dynamic>(key: k2, factory: dynamicFactory),
          ],
        ),
      ));

      // Read from cache: each type should hit its own instance
      final vmStr = ViewModel.readCached<GenericVM<String>>();
      final vmDyn = ViewModel.readCached<GenericVM<dynamic>>();

      // Instances of different types should not be equal
      expect(vmStr, isNot(equals(vmDyn)));

      // Verify each instance's state type and value
      expect(vmStr.state, isA<String>());
      expect(vmStr.state, 'string_state');

      expect(vmDyn.state, isA<dynamic>());
      expect(vmDyn.state, 123);
    });
  });
}

/// A generic ViewModel used to test store isolation across generic types
class GenericVM<T> extends StateViewModel<T> {
  GenericVM({required super.state});
}

/// Test page that creates and caches a ViewModel of the specified type
class GenericPage<T> extends StatefulWidget {
  final DefaultViewModelFactory<GenericVM<T>> factory;

  const GenericPage({super.key, required this.factory});

  @override
  State<GenericPage<T>> createState() => _GenericPageState<T>();
}

class _GenericPageState<T> extends State<GenericPage<T>>
    with ViewModelStateMixin<GenericPage<T>> {
  late final GenericVM<T> _vm;

  @override
  void initState() {
    super.initState();
    _vm = watchViewModel<GenericVM<T>>(factory: widget.factory);
  }

  @override
  Widget build(BuildContext context) {
    // Test page: no UI needed
    return const SizedBox.shrink();
  }
}
