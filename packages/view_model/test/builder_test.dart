import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:view_model/view_model.dart';

import 'test_widget.dart';

void main() {
  group('ViewModelBuilder & CachedViewModelBuilder', () {
    setUp(() {
      ViewModel.initialize(config: ViewModelConfig(logEnable: true));
    });

    testWidgets('ViewModelBuilder rebuilds when ViewModel state changes',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: ViewModelBuilder<TestViewModel>(
          factory: const TestViewModelFactory(initState: "initState"),
          builder: (vm) => Text(vm.state),
        ),
      ));

      expect(find.text('initState'), findsOneWidget);

      final vm = ViewModel.readCached<TestViewModel>();
      vm.setState('updated');
      await tester.pumpAndSettle();

      expect(find.text('updated'), findsOneWidget);
    });

    testWidgets(
        'CachedViewModelBuilder binds by shareKey and rebuilds on change',
        (tester) async {
      const factory =
          TestViewModelFactory(initState: 'key-init', keyV: 'vm-key');

      await tester.pumpWidget(MaterialApp(
        home: Column(children: [
          // Create the instance via TestPage (uses watchViewModel internally)
          const TestPage(factory: factory),
          CachedViewModelBuilder<TestViewModel>(
            key: const Key('cached-widget'),
            shareKey: 'vm-key',
            builder: (vm) => Text('cached:${vm.state}'),
          ),
        ]),
      ));

      expect(find.text('key-init'), findsOneWidget);
      expect(find.text('cached:key-init'), findsOneWidget);

      final vm = ViewModel.readCached<TestViewModel>(key: 'vm-key');
      vm.setState('key-updated');
      await tester.pumpAndSettle();

      expect(find.text('key-updated'), findsOneWidget);
      expect(find.text('cached:key-updated'), findsOneWidget);
    });

    testWidgets('CachedViewModelBuilder binds by tag and rebuilds on change',
        (tester) async {
      const factory = TestViewModelFactory(initState: 'tag-init', tag: 't1');

      await tester.pumpWidget(MaterialApp(
        home: Column(children: [
          // Create the instance via TestPage (uses watchViewModel internally)
          const TestPage(factory: factory),
          CachedViewModelBuilder<TestViewModel>(
            tag: 't1',
            builder: (vm) => Text('cached:${vm.state}'),
          ),
        ]),
      ));

      expect(find.text('tag-init'), findsOneWidget);
      expect(find.text('cached:tag-init'), findsOneWidget);

      final vm = ViewModel.readCached<TestViewModel>(tag: 't1');
      vm.setState('tag-updated');
      await tester.pumpAndSettle();

      expect(find.text('tag-updated'), findsOneWidget);
      expect(find.text('cached:tag-updated'), findsOneWidget);
    });

    testWidgets('CachedViewModelBuilder renders nothing when instance missing',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: CachedViewModelBuilder<TestViewModel>(
          shareKey: 'non-existent',
          builder: (vm) => const Text('should-not-render'),
        ),
      ));

      expect(find.text('should-not-render'), findsNothing);
    });
  });
}
