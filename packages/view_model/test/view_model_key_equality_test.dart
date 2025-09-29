import 'package:flutter_test/flutter_test.dart';
import 'package:view_model/src/get_instance/manager.dart';
import 'package:view_model/view_model.dart';

// A simple key class with an overridden == operator.
class MyKey {
  final String value;

  const MyKey(this.value);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MyKey && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;
}

// A simple ViewModel for testing purposes.
class TestViewModel extends StateViewModel<int> {
  TestViewModel({required int state}) : super(state: state);
}

void main() {
  group('ViewModel Key Equality Tests', () {
    setUp(() {
      ViewModel.initialize(config: ViewModelConfig(logEnable: true));
    });

    tearDown(() {});

    test(
        'instanceManager.getNotifier should return the same instance for different key objects that are equal (==)',
        () {
      // Act: Read the ViewModel instance twice with different key objects that are equal.
      final viewModel1 = instanceManager
          .getNotifier(
            factory: InstanceFactory<TestViewModel>(
              builder: () => TestViewModel(state: 0),
              arg: const InstanceArg(key: MyKey('a')),
            ),
          )
          .instance;

      final viewModel2 = instanceManager
          .getNotifier(
            factory: InstanceFactory<TestViewModel>(
              builder: () => TestViewModel(state: 0),
              arg: const InstanceArg(key: MyKey('a')),
            ),
          )
          .instance;

      // Assert: Verify that both variables point to the exact same instance.
      expect(identical(viewModel1, viewModel2), isTrue);
    });
  });
}
