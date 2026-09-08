import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:view_model/src/view_model/state_store.dart';
import 'package:view_model/view_model.dart';

class _TestBinding<VM extends ViewModel> extends ViewModelBinding {
  _TestBinding(this.spec);

  final ViewModelFactory<VM> spec;

  VM get viewModel => read(spec);
}

class _ResourceViewModel with ViewModel {
  _ResourceViewModel(VoidCallback onDispose) {
    addDispose(onDispose);
  }
}

class _FailingSubscriptionViewModel with ViewModel {
  _FailingSubscriptionViewModel(
    Stream<int> events,
    void Function(int) onEvent,
    VoidCallback onDispose,
  ) {
    final subscription = events.listen(onEvent);
    addDispose(subscription.cancel);
    addDispose(onDispose);
    throw StateError('constructor failed');
  }
}

class _FailingParentViewModel with ViewModel {
  _FailingParentViewModel(
    ViewModelFactory<_ResourceViewModel> childSpec,
    VoidCallback onDispose,
  ) {
    addDispose(onDispose);
    viewModelBinding.read(childSpec);
    throw StateError('parent constructor failed');
  }
}

void main() {
  setUp(ViewModel.reset);
  tearDown(ViewModel.reset);

  for (final watch in [false, true]) {
    test(
      'disposed binding rejects ${watch ? 'watch' : 'read'} tag batches',
      () {
        var disposals = 0;
        final owner = _TestBinding(
          ViewModelSpec<_ResourceViewModel>(
            builder: () => _ResourceViewModel(() => disposals++),
            key: 'lifecycle-regression-tagged-resource',
            tag: 'lifecycle-regression-tag',
          ),
        );
        final disposedBinding = ViewModelBinding();
        addTearDown(owner.dispose);
        addTearDown(disposedBinding.dispose);

        expect(owner.viewModel.refHandler.owners, [owner]);
        disposedBinding.dispose();

        expect(
          () => watch
              ? disposedBinding.watchCachesByTag<_ResourceViewModel>(
                  'lifecycle-regression-tag',
                )
              : disposedBinding.readCachesByTag<_ResourceViewModel>(
                  'lifecycle-regression-tag',
                ),
          throwsA(isA<ViewModelError>()),
        );

        expect(owner.viewModel.refHandler.owners, [owner]);
        expect(owner.viewModel.hasListeners, isFalse);
        owner.dispose();
        expect(disposals, 1);
      },
    );
  }

  test('failed constructor cancels its registered subscription', () {
    final events = StreamController<int>.broadcast(sync: true);
    addTearDown(events.close);
    final received = <int>[];
    var disposals = 0;
    final owner = _TestBinding(
      ViewModelSpec<_FailingSubscriptionViewModel>(
        builder: () => _FailingSubscriptionViewModel(
          events.stream,
          received.add,
          () => disposals++,
        ),
      ),
    );
    addTearDown(owner.dispose);

    expect(() => owner.viewModel, throwsA(isA<StateError>()));
    expect(disposals, 1);
    events.add(1);
    expect(received, isEmpty);

    owner.dispose();
    ViewModel.reset();
    expect(disposals, 1);
  });

  test('successful construction keeps cleanup until normal disposal', () {
    var disposals = 0;
    final owner = _TestBinding(
      ViewModelSpec<_ResourceViewModel>(
        builder: () => _ResourceViewModel(() => disposals++),
      ),
    );
    addTearDown(owner.dispose);

    expect(owner.viewModel.isDisposed, isFalse);
    expect(disposals, 0);

    owner.dispose();
    owner.dispose();
    expect(disposals, 1);
  });

  test('failed parent cleans its resources and committed child once', () {
    var parentDisposals = 0;
    var childDisposals = 0;
    final childSpec = ViewModelSpec<_ResourceViewModel>(
      builder: () => _ResourceViewModel(() => childDisposals++),
    );
    final owner = _TestBinding(
      ViewModelSpec<_FailingParentViewModel>(
        builder: () =>
            _FailingParentViewModel(childSpec, () => parentDisposals++),
      ),
    );
    addTearDown(owner.dispose);

    expect(() => owner.viewModel, throwsA(isA<StateError>()));
    expect(parentDisposals, 1);
    expect(childDisposals, 1);

    owner.dispose();
    ViewModel.reset();
    expect(parentDisposals, 1);
    expect(childDisposals, 1);
  });

  test('rollback after untracked disposal does not repeat cleanup', () {
    var disposals = 0;
    final owner = _TestBinding(
      ViewModelSpec<_ResourceViewModel>(
        builder: () {
          ViewModel.reset();
          return _ResourceViewModel(() => disposals++);
        },
      ),
    );
    addTearDown(owner.dispose);

    expect(() => owner.viewModel, throwsA(isA<ViewModelError>()));
    expect(disposals, 1);

    owner.dispose();
    ViewModel.reset();
    expect(disposals, 1);
  });
}
