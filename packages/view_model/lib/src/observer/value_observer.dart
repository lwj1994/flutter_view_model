import 'package:flutter/widgets.dart';
import 'package:view_model/view_model.dart';

/// A class that holds a value and can be observed by an [ObserverBuilder].
///
/// It allows reading the current value and setting a new one, which will
/// trigger a rebuild in any listening [ObserverBuilder].
///
/// The data can be shared and identified by [shareKey].
class ObservableValue<T> {
  /// A key to identify and share this value across different [ObserverBuilder]s.
  /// If not provided, a unique key is automatically created, making the value local.
  final Object shareKey;

  T _value;

  /// The current value.
  /// It reads from the local cache first. If a shared ViewModel is found,
  /// it syncs with the state from the ViewModel.
  T get value {
    final vm =
        ViewModel.maybeReadCached<_ObserveDataViewModel<T>>(key: shareKey);
    if (vm != null && vm.state != _value) {
      _value = vm.state;
    }
    return _value;
  }

  set value(T newValue) {
    if (value == newValue) return;

    _value = newValue; // Always update the local value

    final vm =
        ViewModel.maybeReadCached<_ObserveDataViewModel<T>>(key: shareKey);

    if (vm != null) {
      // ignore: invalid_use_of_protected_member
      vm.setState(newValue);
    }
  }

  /// Creates an observable value.
  ///
  /// If a [shareKey] is provided, it will be used to identify this value.
  /// Otherwise, a unique key is automatically created, making this value local.
  ObservableValue(T initialValue, {Object? shareKey})
      : _value = initialValue,
        shareKey = shareKey ?? Object();
}

class _ObserveDataViewModelFactory<T>
    with ViewModelFactory<_ObserveDataViewModel<T>> {
  final T data;
  final Object shareKey;

  _ObserveDataViewModelFactory({
    required this.data,
    required this.shareKey,
  });

  @override
  _ObserveDataViewModel<T> build() {
    return _ObserveDataViewModel<T>(state: data);
  }

  @override
  Object? key() {
    return shareKey;
  }
}

class _ObserveDataViewModel<T> extends StateViewModel<T> {
  _ObserveDataViewModel({required super.state});
}

/// A widget that listens to an [ObservableValue] and rebuilds whenever the
/// value changes.
class ObserverBuilder<T> extends StatefulWidget {
  final ObservableValue<T> observable;
  final Widget Function(BuildContext) builder;

  const ObserverBuilder({
    required this.observable,
    required this.builder,
    Key? key,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _ObserverBuilderState<T>();
  }
}

class _ObserverBuilderState<T> extends State<ObserverBuilder<T>>
    with ViewModelStateMixin<ObserverBuilder<T>> {
  late _ObserveDataViewModel<T> _viewModel;

  @override
  void initState() {
    super.initState();
    if (T == dynamic) {
      throw UnsupportedError(
          "ObserverBuilder<T> requires a specific type 'T', but 'dynamic' was provided. "
          "Please specify a concrete type (e.g., ObserverBuilder<int>(...)).");
    }
    _init();
  }

  void _init() {
    _viewModel = watchViewModel<_ObserveDataViewModel<T>>(
      factory: _ObserveDataViewModelFactory<T>(
        data: widget.observable.value,
        shareKey: widget.observable.shareKey,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Rebuilds when the view model's state changes.
    // The builder can access the latest value via `widget.observable.value`.
    _viewModel.state;
    return widget.builder(context);
  }
}

/// A widget that listens to two [ObservableValue]s and rebuilds whenever either
/// value changes.
class ObserverBuilder2<T1, T2> extends StatefulWidget {
  final ObservableValue<T1> observable1;
  final ObservableValue<T2> observable2;
  final Widget Function(BuildContext) builder;

  const ObserverBuilder2({
    required this.observable1,
    required this.observable2,
    required this.builder,
    Key? key,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _ObserverBuilder2State<T1, T2>();
  }
}

class _ObserverBuilder2State<T1, T2> extends State<ObserverBuilder2<T1, T2>>
    with ViewModelStateMixin<ObserverBuilder2<T1, T2>> {
  late _ObserveDataViewModel<T1> _viewModel1;
  late _ObserveDataViewModel<T2> _viewModel2;

  @override
  void initState() {
    super.initState();
    if (T1 == dynamic || T2 == dynamic) {
      throw UnsupportedError(
          "ObserverBuilder2<T1, T2> requires specific types, but 'dynamic' was provided.");
    }
    _viewModel1 = watchViewModel<_ObserveDataViewModel<T1>>(
      factory: _ObserveDataViewModelFactory<T1>(
        data: widget.observable1.value,
        shareKey: widget.observable1.shareKey,
      ),
    );
    _viewModel2 = watchViewModel<_ObserveDataViewModel<T2>>(
      factory: _ObserveDataViewModelFactory<T2>(
        data: widget.observable2.value,
        shareKey: widget.observable2.shareKey,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Rebuilds when any of the view models' state changes.
    // The builder can access the latest values via `widget.observableX.value`.
    _viewModel1.state;
    _viewModel2.state;
    return widget.builder(context);
  }
}

/// A widget that listens to three [ObservableValue]s and rebuilds whenever any
/// value changes.
class ObserverBuilder3<T1, T2, T3> extends StatefulWidget {
  final ObservableValue<T1> observable1;
  final ObservableValue<T2> observable2;
  final ObservableValue<T3> observable3;
  final Widget Function(BuildContext) builder;

  const ObserverBuilder3({
    required this.observable1,
    required this.observable2,
    required this.observable3,
    required this.builder,
    Key? key,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _ObserverBuilder3State<T1, T2, T3>();
  }
}

class _ObserverBuilder3State<T1, T2, T3>
    extends State<ObserverBuilder3<T1, T2, T3>>
    with ViewModelStateMixin<ObserverBuilder3<T1, T2, T3>> {
  late _ObserveDataViewModel<T1> _viewModel1;
  late _ObserveDataViewModel<T2> _viewModel2;
  late _ObserveDataViewModel<T3> _viewModel3;

  @override
  void initState() {
    super.initState();
    if (T1 == dynamic || T2 == dynamic || T3 == dynamic) {
      throw UnsupportedError(
          "ObserverBuilder3<T1, T2, T3> requires specific types, but 'dynamic' was provided.");
    }
    _viewModel1 = watchViewModel<_ObserveDataViewModel<T1>>(
      factory: _ObserveDataViewModelFactory<T1>(
        data: widget.observable1.value,
        shareKey: widget.observable1.shareKey,
      ),
    );
    _viewModel2 = watchViewModel<_ObserveDataViewModel<T2>>(
      factory: _ObserveDataViewModelFactory<T2>(
        data: widget.observable2.value,
        shareKey: widget.observable2.shareKey,
      ),
    );
    _viewModel3 = watchViewModel<_ObserveDataViewModel<T3>>(
      factory: _ObserveDataViewModelFactory<T3>(
        data: widget.observable3.value,
        shareKey: widget.observable3.shareKey,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Rebuilds when any of the view models' state changes.
    // The builder can access the latest values via `widget.observableX.value`.
    _viewModel1.state;
    _viewModel2.state;
    _viewModel3.state;
    return widget.builder(context);
  }
}
