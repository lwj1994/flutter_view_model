import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:view_model/src/view_model/state_store.dart';
import 'package:view_model/src/view_model/util.dart';
import 'package:view_model/view_model.dart';

class _MissingVm with ViewModel {}

void main() {
  var assertionsEnabled = false;
  assert(() {
    assertionsEnabled = true;
    return true;
  }());
  setUp(ViewModel.reset);
  tearDown(ViewModel.reset);

  test('assertion mode matches the requested debug or release conditions', () {
    expect(assertionsEnabled, kDebugMode);
  });

  test('binding names use only the runtime type outside debug mode', () {
    final owner = ViewModelBinding();
    addTearDown(owner.dispose);
    expect(owner.getName(),
        kDebugMode ? contains('ViewModelBinding') : 'ViewModelBinding');
    if (!kDebugMode) {
      final locator = StackPathLocator(captureTrace: () {
        fail('Non-debug names must not capture a stack.');
      });
      expect(locator.getCurrentObjectPath(), isEmpty);
      expect(locator.ready, isFalse);
    }
  });

  testWidgets('missing cached builder asserts or reports and renders empty',
      (tester) async {
    final errors = <(Object, ErrorType)>[];
    ViewModel.initialize(
        config: ViewModelConfig(
      onError: (error, _, type) => errors.add((error, type)),
    ));
    await tester.pumpWidget(CachedViewModelBuilder<_MissingVm>(
      shareKey: 'missing',
      builder: (_) => const Text('unexpected'),
    ));
    if (assertionsEnabled) {
      expect(tester.takeException(), isA<ViewModelError>());
      expect(errors, isEmpty);
    } else {
      expect(tester.takeException(), isNull);
      expect(errors.single.$1, isA<ViewModelError>());
      expect(errors.single.$1.toString(), contains('missing'));
      expect(errors.single.$2, ErrorType.listener);
      expect(find.byType(SizedBox), findsOneWidget);
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
