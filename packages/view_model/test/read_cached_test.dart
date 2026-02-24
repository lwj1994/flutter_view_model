import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:view_model/src/view_model/state_store.dart';
import 'package:view_model/view_model.dart';

import 'test_widget.dart';

/// Test cases for ViewModel.readCached static method
///
/// This test file covers various scenarios for the readCached method:
/// - Finding ViewModels by key
/// - Finding ViewModels by tag
/// - Handling disposed ViewModels
/// - Error cases when ViewModels don't exist
void main() {
  group('ViewModel.readCached Tests', () {
    setUp(() {
      ViewModel.initialize(config: ViewModelConfig(isLoggingEnabled: true));
    });

    testWidgets('should find ViewModel by key', (tester) async {
      const testKey = 'test_key_123';
      const testFactory = TestViewModelFactory(
        keyV: testKey,
        initState: 'initial_state',
      );

      // Create a widget that creates a ViewModel with a specific key
      final widgetKey = GlobalKey();
      await tester.pumpWidget(MaterialApp(
        home: TestPage(
          key: widgetKey,
          factory: testFactory,
        ),
      ));

      final state = widgetKey.currentState as TestPageState;

      // Create the ViewModel first
      final originalVM = state.viewModelBinding.read(testFactory);
      originalVM.setState('updated_state');

      // Now test readCached with key
      final cachedVM = ViewModel.readCached<TestViewModel>(key: testKey);

      expect(cachedVM, equals(originalVM));
      expect(cachedVM.state, equals('updated_state'));
    });

    testWidgets('should find ViewModel by tag', (tester) async {
      const testTag = 'test_tag_456';
      const testFactory = TestViewModelFactory(
        tagV: testTag,
        initState: 'tagged_state',
      );

      // Create a widget that creates a ViewModel with a specific tag
      final widgetKey = GlobalKey();
      await tester.pumpWidget(MaterialApp(
        home: TestPage(
          key: widgetKey,
          factory: testFactory,
        ),
      ));

      final state = widgetKey.currentState as TestPageState;

      // Create the ViewModel first
      final originalVM = state.viewModelBinding.read(testFactory);
      originalVM.setState('tagged_updated_state');

      // Now test readCached with tag
      final cachedVM = ViewModel.readCached<TestViewModel>(tag: testTag);

      expect(cachedVM, equals(originalVM));
      expect(cachedVM.state, equals('tagged_updated_state'));
    });

    testWidgets('should prioritize key over tag when both are provided',
        (tester) async {
      const testKey = 'priority_key';
      const testTag = 'priority_tag';

      // Create two ViewModels - one with key, one with tag
      const keyFactory = TestViewModelFactory(
        keyV: testKey,
        initState: 'key_state',
      );

      const tagFactory = TestViewModelFactory(
        tagV: testTag,
        initState: 'tag_state',
      );

      final widgetKey1 = GlobalKey();
      final widgetKey2 = GlobalKey();

      await tester.pumpWidget(MaterialApp(
        home: Column(
          children: [
            TestPage(
              key: widgetKey1,
              factory: keyFactory,
            ),
            TestPage(
              key: widgetKey2,
              factory: tagFactory,
            ),
          ],
        ),
      ));

      final state1 = widgetKey1.currentState as TestPageState;
      final state2 = widgetKey2.currentState as TestPageState;

      // Create both ViewModels
      final keyVM = state1.viewModelBinding.read(keyFactory);
      final tagVM = state2.viewModelBinding.read(tagFactory);

      keyVM.setState('key_updated');
      tagVM.setState('tag_updated');

      // Test readCached with both key and tag - should return the key-based
      // ViewModel.
      final cachedVM = ViewModel.readCached<TestViewModel>(
        key: testKey,
        tag: testTag,
      );

      expect(cachedVM, equals(keyVM));
      expect(cachedVM.state, equals('key_updated'));
    });

    testWidgets('should find latest ViewModel when no key or tag provided',
        (tester) async {
      const factory1 = TestViewModelFactory(initState: 'first_vm');
      const factory2 = TestViewModelFactory(initState: 'second_vm');

      final widgetKey1 = GlobalKey();
      final widgetKey2 = GlobalKey();

      await tester.pumpWidget(MaterialApp(
        home: Column(
          children: [
            TestPage(
              key: widgetKey1,
              factory: factory1,
            ),
            TestPage(
              key: widgetKey2,
              factory: factory2,
            ),
          ],
        ),
      ));

      final state1 = widgetKey1.currentState as TestPageState;
      final state2 = widgetKey2.currentState as TestPageState;

      // Create ViewModels in order
      final vm1 = state1.viewModelBinding.read(factory1);
      await tester.pump(); // Allow time for creation

      final vm2 = state2.viewModelBinding.read(factory2);
      vm2.setState('latest_vm_state');

      // Test readCached without key or tag - should return the latest created
      // ViewModel.
      final cachedVM = ViewModel.readCached<TestViewModel>();

      expect(cachedVM, equals(vm2));
      expect(cachedVM.state, equals('latest_vm_state'));
    });

    testWidgets('should handle disposed ViewModel correctly', (tester) async {
      const testKey = 'disposed_key';
      const testFactory = TestViewModelFactory(
        keyV: testKey,
        initState: 'will_be_disposed',
      );

      final widgetKey = GlobalKey();
      await tester.pumpWidget(MaterialApp(
        home: TestPage(
          key: widgetKey,
          factory: testFactory,
        ),
      ));

      final state = widgetKey.currentState as TestPageState;
      final vm = state.viewModelBinding.read(testFactory);

      // Verify we can read cached before dispose
      final cachedBeforeDispose =
          ViewModel.readCached<TestViewModel>(key: testKey);
      expect(cachedBeforeDispose, equals(vm));
      expect(cachedBeforeDispose.isDisposed, isFalse);

      // Remove the widget to trigger proper disposal through the instance
      // manager.
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: Text('Empty')),
      ));

      // After widget disposal, the ViewModel should be disposed
      // and readCached should throw an error
      expect(() => ViewModel.readCached<TestViewModel>(key: testKey),
          throwsA(isA<ViewModelError>()));
    });

    testWidgets('should throw error when ViewModel with key not found',
        (tester) async {
      // Test readCached with non-existent key
      expect(
        () => ViewModel.readCached<TestViewModel>(key: 'non_existent_key'),
        throwsA(isA<ViewModelError>()),
      );
    });

    testWidgets('should throw error when ViewModel with tag not found',
        (tester) async {
      // Test readCached with non-existent tag
      expect(
        () => ViewModel.readCached<TestViewModel>(tag: 'non_existent_tag'),
        throwsA(isA<ViewModelError>()),
      );
    });

    testWidgets('should throw error when no ViewModel of type exists',
        (tester) async {
      // Test readCached when no ViewModel of the specified type exists
      expect(
        () => ViewModel.readCached<TestViewModel>(),
        throwsA(isA<ViewModelError>()),
      );
    });

    testWidgets('should work with different ViewModel types', (tester) async {
      // Create a custom ViewModel type for this test
      const customFactory = TestViewModelFactory(
        keyV: 'custom_key',
        initState: 'custom_state',
      );

      final widgetKey = GlobalKey();
      await tester.pumpWidget(MaterialApp(
        home: TestPage(
          key: widgetKey,
          factory: customFactory,
        ),
      ));

      final state = widgetKey.currentState as TestPageState;
      final originalVM = state.viewModelBinding.read(customFactory);
      originalVM.setState('custom_updated');

      // Test readCached with specific type
      final cachedVM = ViewModel.readCached<TestViewModel>(key: 'custom_key');

      expect(cachedVM, isA<TestViewModel>());
      expect(cachedVM, equals(originalVM));
      expect(cachedVM.state, equals('custom_updated'));
    });
  });
}
