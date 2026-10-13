import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:view_model/src/view_model/app_lifecycle_observer.dart';
import 'package:view_model/src/view_model/pause_aware.dart';
import 'package:view_model/view_model.dart';

class _StateVm extends StateViewModel<int> {
  _StateVm() : super(state: 0);
  void setValue(int value) => setState(value);
}

final _stateSpec = ViewModelSpec<_StateVm>(builder: _StateVm.new);

class _Owner with ViewModelBinding {
  _StateVm get vm => read(_stateSpec);
}

class _LegacyStateless extends StatelessWidget with ViewModelStatelessMixin {
  _LegacyStateless();
  @override
  Widget build(BuildContext context) {
    expect(vef, same(viewModelBinding));
    return Text('${vef.read(_stateSpec).state}');
  }
}

class _LegacyStateful extends StatefulWidget {
  const _LegacyStateful();
  @override
  State<_LegacyStateful> createState() => _LegacyState();
}

class _LegacyState extends State<_LegacyStateful>
    with ViewModelStateMixin<_LegacyStateful> {
  @override
  Widget build(BuildContext context) {
    expect(vef, same(viewModelBinding));
    return Text('${vef.read(_stateSpec).state}');
  }
}

class _Provider with ViewModelBindingPauseProvider {
  _Provider({this.cleanupError});
  final Object? cleanupError;
  final events = StreamController<bool>();
  bool disposed = false;
  @override
  Stream<bool> get onPauseStateChanged => events.stream;
  @override
  void dispose() {
    disposed = true;
    events.close();
    super.dispose();
    if (cleanupError != null) throw cleanupError!;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(ViewModel.reset);
  tearDown(ViewModel.reset);

  testWidgets('legacy widget accessors keep the mounted binding',
      (tester) async {
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Column(children: [_LegacyStateless(), const _LegacyStateful()]),
    ));
    expect(find.text('0'), findsNWidgets(2));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final selector in [true, false]) {
    testWidgets('selector=$selector defers changes made during build',
        (tester) async {
      final owner = _Owner();
      addTearDown(owner.dispose);
      Widget buildValue(int value) {
        if (value == 0) owner.vm.setValue(1);
        return Text('$value');
      }

      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: selector
            ? StateViewModelSelector<int, int>(
                viewModel: owner.vm,
                selector: (value) => value,
                builder: (_, value) => buildValue(value),
              )
            : StateViewModelValueWatcher<int>(
                viewModel: owner.vm,
                selectors: [(value) => value],
                builder: buildValue,
              ),
      ));
      await tester.pump();
      expect(find.text('1'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      owner.vm.setValue(2);
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }

  test('pause stream errors preserve the last state and later transitions',
      () async {
    final errors = <(Object, ErrorType)>[];
    ViewModel.initialize(
        config: ViewModelConfig(
      onError: (error, _, type) => errors.add((error, type)),
    ));
    final provider = _Provider();
    final transitions = <bool>[];
    final controller = PauseAwareController(
      providers: [provider],
      disposableProviders: [provider],
      onWidgetPause: () => transitions.add(true),
      onWidgetResume: () => transitions.add(false),
    );
    addTearDown(controller.dispose);
    final failure = StateError('pause source');
    provider.events.add(true);
    provider.events.addError(failure, StackTrace.current);
    provider.events.add(false);
    await Future<void>.delayed(Duration.zero);
    expect(transitions, [true, false]);
    expect(controller.isPaused, isFalse);
    expect(errors, [(failure, ErrorType.pauseResume)]);
    controller.dispose();
    expect(provider.disposed, isTrue);
  });

  test('pause provider disposal failures do not skip the other providers', () {
    final errors = <Object>[];
    ViewModel.initialize(config: ViewModelConfig(
      onError: (error, _, type) {
        expect(type, ErrorType.dispose);
        errors.add(error);
      },
    ));
    final failure = StateError('provider cleanup');
    final first = _Provider(cleanupError: failure);
    final second = _Provider();
    final controller = PauseAwareController(
      providers: [first, second],
      disposableProviders: [first, second],
      onWidgetPause: () {},
      onWidgetResume: () {},
    );
    addTearDown(controller.dispose);
    controller.dispose();
    expect(first.disposed, isTrue);
    expect(second.disposed, isTrue);
    expect(errors, [failure]);
  });

  test('app hidden and resumed states produce pause and resume events',
      () async {
    final provider = AppPauseProvider();
    final states = <bool>[];
    final subscription = provider.onPauseStateChanged.listen(states.add);
    addTearDown(provider.dispose);
    addTearDown(subscription.cancel);
    AppLifecycleObserver().didChangeAppLifecycleState(AppLifecycleState.hidden);
    AppLifecycleObserver()
        .didChangeAppLifecycleState(AppLifecycleState.resumed);
    await Future<void>.delayed(Duration.zero);
    expect(states, [true, false]);
  });

  test('popping a route pauses its lifecycle provider', () async {
    final provider = PageRoutePauseProvider();
    final states = <bool>[];
    final subscription = provider.onPauseStateChanged.listen(states.add);
    addTearDown(provider.dispose);
    addTearDown(subscription.cancel);
    provider.didPop();
    await Future<void>.delayed(Duration.zero);
    expect(states, [true]);
  });
}
