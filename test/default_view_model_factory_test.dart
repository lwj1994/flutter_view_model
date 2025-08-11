import 'package:flutter_test/flutter_test.dart';
import 'package:view_model/view_model.dart';

// Test ViewModel implementations
class TestViewModel extends ViewModel {
  final String name;
  TestViewModel(this.name);
}

class CounterViewModel extends StateViewModel<int> {
  CounterViewModel() : super(state: 0);

  void increment() {
    setState(state + 1);
  }
}

// Test enum for tag testing
enum TestTag { primary, secondary }

void main() {
  group('DefaultViewModelFactory', () {
    test('should create factory with required builder', () {
      final factory = DefaultViewModelFactory<TestViewModel>(
        builder: () => TestViewModel('test'),
      );

      expect(factory.builder, isNotNull);
      expect(factory.isSingleton, false);
      expect(factory.key(), isNull);
      expect(factory.getTag(), isNull);
    });

    test('should build ViewModel instance correctly', () {
      final factory = DefaultViewModelFactory<TestViewModel>(
        builder: () => TestViewModel('test_name'),
      );

      final viewModel = factory.build();
      expect(viewModel, isA<TestViewModel>());
      expect(viewModel.name, equals('test_name'));
    });

    test('should handle custom key correctly', () {
      const customKey = 'my_custom_key';
      final factory = DefaultViewModelFactory<TestViewModel>(
        builder: () => TestViewModel('test'),
        key: customKey,
      );

      expect(factory.key(), equals(customKey));
    });

    test('should handle null key correctly', () {
      final factory = DefaultViewModelFactory<TestViewModel>(
        builder: () => TestViewModel('test'),
        key: null,
      );

      // When key is null and not singleton, should return null
      expect(factory.key(), isNull);
    });

    test('should handle singleton mode correctly', () {
      final factory = DefaultViewModelFactory<TestViewModel>(
        builder: () => TestViewModel('test'),
        isSingleton: true,
      );

      expect(factory.singleton(), isTrue);
      expect(factory.key(), isNotNull); // Singleton should have a default key
    });

    test('should prioritize custom key over singleton default key', () {
      const customKey = 'priority_key';
      final factory = DefaultViewModelFactory<TestViewModel>(
        builder: () => TestViewModel('test'),
        key: customKey,
        isSingleton: true,
      );

      expect(factory.singleton(), isTrue);
      expect(factory.key(), equals(customKey)); // Custom key should take precedence
    });

    test('should handle custom tag correctly', () {
      const customTag = 'my_tag';
      final factory = DefaultViewModelFactory<TestViewModel>(
        builder: () => TestViewModel('test'),
        tag: customTag,
      );

      expect(factory.getTag(), equals(customTag));
    });

    test('should handle object tag correctly', () {
      final customTag = {'type': 'test', 'id': 123};
      final factory = DefaultViewModelFactory<TestViewModel>(
        builder: () => TestViewModel('test'),
        tag: customTag,
      );

      expect(factory.getTag(), equals(customTag));
    });

    test('should handle null tag correctly', () {
      final factory = DefaultViewModelFactory<TestViewModel>(
        builder: () => TestViewModel('test'),
        tag: null,
      );

      expect(factory.getTag(), isNull);
    });

    test('should work with StateViewModel', () {
      final factory = DefaultViewModelFactory<CounterViewModel>(
        builder: () => CounterViewModel(),
      );

      final viewModel = factory.build();
      expect(viewModel, isA<CounterViewModel>());
      expect(viewModel.state, equals(0));

      viewModel.increment();
      expect(viewModel.state, equals(1));
    });

    test('should handle all parameters together', () {
      const customKey = 'full_test_key';
      const customTag = 'full_test_tag';
      final factory = DefaultViewModelFactory<TestViewModel>(
        builder: () => TestViewModel('full_test'),
        key: customKey,
        tag: customTag,
        isSingleton: true,
      );

      expect(factory.key(), equals(customKey));
      expect(factory.getTag(), equals(customTag));
      expect(factory.singleton(), isTrue);

      final viewModel = factory.build();
      expect(viewModel.name, equals('full_test'));
    });

    test('should create different instances when not singleton', () {
      final factory = DefaultViewModelFactory<TestViewModel>(
        builder: () => TestViewModel('instance'),
        isSingleton: false,
      );

      final instance1 = factory.build();
      final instance2 = factory.build();

      expect(instance1, isNot(same(instance2)));
      expect(instance1.name, equals(instance2.name));
    });

    test('should handle complex builder logic', () {
      int counter = 0;
      final factory = DefaultViewModelFactory<TestViewModel>(
        builder: () {
          counter++;
          return TestViewModel('instance_$counter');
        },
      );

      final instance1 = factory.build();
      final instance2 = factory.build();

      expect(instance1.name, equals('instance_1'));
      expect(instance2.name, equals('instance_2'));
      expect(counter, equals(2));
    });

    test('should handle enum tag', () {
      final factory = DefaultViewModelFactory<TestViewModel>(
        builder: () => TestViewModel('test'),
        tag: TestTag.primary,
      );

      expect(factory.getTag(), equals(TestTag.primary));
    });

    test('should maintain immutability of configuration', () {
      const originalKey = 'original_key';
      const originalTag = 'original_tag';

      final factory = DefaultViewModelFactory<TestViewModel>(
        builder: () => TestViewModel('test'),
        key: originalKey,
        tag: originalTag,
        isSingleton: true,
      );

      // Multiple calls should return same values
      expect(factory.key(), equals(originalKey));
      expect(factory.key(), equals(originalKey));
      expect(factory.getTag(), equals(originalTag));
      expect(factory.getTag(), equals(originalTag));
      expect(factory.singleton(), isTrue);
      expect(factory.singleton(), isTrue);
    });
  });
}
