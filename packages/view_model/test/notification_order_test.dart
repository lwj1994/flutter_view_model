import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:view_model/view_model.dart';

class _CounterViewModel extends StateViewModel<int> {
  _CounterViewModel() : super(state: 0);

  void set(int value) => setState(value);
}

final _counterSpec = ViewModelSpec<_CounterViewModel>(
  builder: _CounterViewModel.new,
  key: 'notification-order-source',
);

class _BranchViewModel with ViewModel {
  _BranchViewModel() {
    viewModelBinding.listen(
      _counterSpec,
      onChanged: () {
        value = viewModelBinding.read(_counterSpec).state;
        notifyListeners();
      },
    );
  }

  int value = 0;
}

final _leftSpec = ViewModelSpec<_BranchViewModel>(
  builder: _BranchViewModel.new,
  key: 'notification-order-left',
);
final _rightSpec = ViewModelSpec<_BranchViewModel>(
  builder: _BranchViewModel.new,
  key: 'notification-order-right',
);

class _AggregateViewModel with ViewModel {
  _BranchViewModel get left => viewModelBinding.watch(_leftSpec);
  _BranchViewModel get right => viewModelBinding.watch(_rightSpec);

  int get total => left.value + right.value;
}

final _aggregateSpec = ViewModelSpec<_AggregateViewModel>(
  builder: _AggregateViewModel.new,
);

class _ListeningTotalViewModel extends StateViewModel<int> {
  _ListeningTotalViewModel() : super(state: 0) {
    viewModelBinding.listen(
      _aggregateSpec,
      onChanged: () {
        setState(aggregate.total);
      },
    );
    // Resolve both branches before the source emits its first update.
    setState(aggregate.total);
  }

  _AggregateViewModel get aggregate => viewModelBinding.read(_aggregateSpec);
}

final _totalSpec = ViewModelSpec<_ListeningTotalViewModel>(
  builder: _ListeningTotalViewModel.new,
);

class _TestBinding with ViewModelBinding {
  int updates = 0;

  _CounterViewModel get counter => read(_counterSpec);
  _ListeningTotalViewModel get total => watch(_totalSpec);

  @override
  void onUpdate() {
    super.onUpdate();
    updates++;
  }
}

void main() {
  setUp(ViewModel.reset);
  tearDown(ViewModel.reset);

  test('reentrant state listeners receive transitions in order', () {
    final binding = _TestBinding();
    addTearDown(binding.dispose);
    binding.watch(_counterSpec);
    final events = <(int?, int)>[];
    final selected = <int>[];
    binding.listenState(
      _counterSpec,
      onChanged: (previous, current) {
        if (current == 1) binding.counter.set(2);
      },
    );
    binding.listenState<_CounterViewModel, int>(
      _counterSpec,
      onChanged: (previous, current) => events.add((previous, current)),
    );
    binding.listenStateSelect<_CounterViewModel, int, int>(
      _counterSpec,
      selector: (state) => state,
      onChanged: (previous, current) => selected.add(current),
    );
    binding.updates = 0;

    binding.counter.set(1);

    expect(binding.counter.state, 2);
    expect(events, [(0, 1), (1, 2)]);
    expect(selected, [1, 2]);
    expect(binding.updates, 1);
  });

  test('reentrant listen coalesces every root without dropping events', () {
    final binding = _TestBinding();
    final otherBinding = _TestBinding();
    addTearDown(binding.dispose);
    addTearDown(otherBinding.dispose);
    binding.watch(_counterSpec);
    otherBinding.watch(_counterSpec);
    final notifications = <int>[];
    final events = <(int?, int)>[];
    final selected = <int>[];
    binding.listenState<_CounterViewModel, int>(
      _counterSpec,
      onChanged: (previous, current) => events.add((previous, current)),
    );
    binding.listenStateSelect<_CounterViewModel, int, int>(
      _counterSpec,
      selector: (state) => state,
      onChanged: (previous, current) => selected.add(current),
    );
    binding.listen(
      _counterSpec,
      onChanged: () {
        notifications.add(binding.counter.state);
        if (binding.counter.state == 1) binding.counter.set(2);
      },
    );
    binding.updates = 0;
    otherBinding.updates = 0;

    binding.counter.set(1);

    expect(binding.counter.state, 2);
    expect(notifications, [1, 2]);
    expect(events, [(0, 1), (1, 2)]);
    expect(selected, [1, 2]);
    expect(binding.updates, 1);
    expect(otherBinding.updates, 1);

    // An independent synchronous call must start a fresh transaction.
    binding.counter.set(3);

    expect(notifications, [1, 2, 3]);
    expect(events, [(0, 1), (1, 2), (2, 3)]);
    expect(selected, [1, 2, 3]);
    expect(binding.updates, 2);
    expect(otherBinding.updates, 2);
  });

  test('microtask state updates start a fresh refresh transaction', () async {
    final binding = _TestBinding();
    addTearDown(binding.dispose);
    binding.watch(_counterSpec);
    final notifications = <int>[];
    Future<void>? followUp;
    binding.listen(
      _counterSpec,
      onChanged: () {
        notifications.add(binding.counter.state);
        if (binding.counter.state == 1) {
          followUp = Future<void>.microtask(() => binding.counter.set(2));
        }
      },
    );
    binding.updates = 0;

    binding.counter.set(1);

    expect(binding.counter.state, 1);
    expect(notifications, [1]);
    expect(binding.updates, 1);
    expect(followUp, isNotNull);

    await followUp!;

    expect(binding.counter.state, 2);
    expect(notifications, [1, 2]);
    expect(binding.updates, 2);
  });

  testWidgets('selector renders the latest state after a reentrant update', (
    tester,
  ) async {
    final binding = _TestBinding();
    addTearDown(binding.dispose);
    binding.listenState(
      _counterSpec,
      onChanged: (previous, current) {
        if (current == 1) binding.counter.set(2);
      },
    );
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: StateViewModelSelector<int, int>(
          viewModel: binding.counter,
          selector: (state) => state,
          builder: (context, value) => Text('Value: $value'),
        ),
      ),
    );

    binding.counter.set(1);
    await tester.pump();

    expect(binding.counter.state, 2);
    expect(find.text('Value: 2'), findsOneWidget);
    expect(find.text('Value: 1'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('disposing during delivery drops remaining and queued callbacks', () {
    final binding = _TestBinding();
    addTearDown(binding.dispose);
    final events = <int>[];
    binding.listenState(
      _counterSpec,
      onChanged: (previous, current) {
        if (current == 1) {
          binding.counter.set(2);
          binding.dispose();
        }
      },
    );
    binding.listenState<_CounterViewModel, int>(
      _counterSpec,
      onChanged: (previous, current) => events.add(current),
    );

    binding.counter.set(1);

    expect(events, isEmpty);
    expect(binding.isDisposed, isTrue);
  });

  test('listen through a watched diamond reaches the final derived value', () {
    final binding = _TestBinding();
    addTearDown(binding.dispose);
    final totals = <int>[];
    expect(binding.total.state, 0);
    binding.listenState<_ListeningTotalViewModel, int>(
      _totalSpec,
      onChanged: (previous, current) => totals.add(current),
    );
    binding.updates = 0;

    binding.counter.set(1);

    // Both branches recompute. Explicit listeners see both values, while the
    // root only needs one refresh request to display the final state.
    expect(totals, [1, 2]);
    expect(binding.total.state, 2);
    expect(binding.updates, 1);
  });
}
