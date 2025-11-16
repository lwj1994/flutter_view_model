import 'package:flutter/widgets.dart';
import 'package:view_model/src/get_instance/manager.dart';
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

  final T initialValue;

  /// Returns the current value proxied from the underlying shared StateViewModel.
  /// The value is sourced from the shared instance identified by `shareKey`.
  T get value {
    return _vm.state;
  }

  late _ObserveDataViewModel<T> _vm;

  /// Updates the underlying shared StateViewModel state and notifies observers.
  set value(T newValue) {
    // ignore: invalid_use_of_protected_member
    _vm.setState(newValue);
  }

  /// Creates an observable value.
  ///
  /// If a [shareKey] is provided, it will be used to identify this value.
  /// Otherwise, a unique key is automatically created, making this value local.
  ObservableValue(this.initialValue, {Object? shareKey})
      : this.shareKey = shareKey ?? Object() {
    _vm = instanceManager.get<_ObserveDataViewModel<T>>(
        factory: InstanceFactory(
            builder: () {
              return _ObserveDataViewModelFactory<T>(
                      data: initialValue, shareKey: this.shareKey)
                  .build();
            },
            arg: InstanceArg(key: this.shareKey)));
  }
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

  /// Builder that receives the latest value; `BuildContext` is not required.
  final Widget Function(T value) builder;

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
  /// Subscribes to the shared StateViewModel identified by `observable.shareKey`
  /// and passes its current state to `builder` as `data`.
  @override
  Widget build(BuildContext context) {
    // Rebuilds when the view model's state changes; latest value
    // is provided to `builder`.
    return widget.builder(watchCachedViewModel<_ObserveDataViewModel<T>>(
      key: widget.observable.shareKey,
    ).state);
  }
}

/// A widget that listens to two [ObservableValue]s and rebuilds whenever either
/// value changes.
class ObserverBuilder2<T1, T2> extends StatefulWidget {
  final ObservableValue<T1> observable1;
  final ObservableValue<T2> observable2;

  /// Builder that receives latest values from two observables;
  /// no `BuildContext` needed.
  final Widget Function(T1 value1, T2 value2) builder;

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
  /// Subscribes to two shared StateViewModels identified by `observable1.shareKey`
  /// and `observable2.shareKey`, passing their current states to `builder` as
  /// `value1` and `value2`.
  @override
  Widget build(BuildContext context) {
    // Rebuilds when any view model's state changes; latest values
    // are passed to `builder`.
    return widget.builder(
      watchCachedViewModel<_ObserveDataViewModel<T1>>(
        key: widget.observable1.shareKey,
      ).state,
      watchCachedViewModel<_ObserveDataViewModel<T2>>(
        key: widget.observable2.shareKey,
      ).state,
    );
  }
}

/// A widget that listens to three [ObservableValue]s and rebuilds whenever any
/// value changes.
class ObserverBuilder3<T1, T2, T3> extends StatefulWidget {
  final ObservableValue<T1> observable1;
  final ObservableValue<T2> observable2;
  final ObservableValue<T3> observable3;

  /// Builder that receives latest values from three observables;
  /// no `BuildContext` needed.
  final Widget Function(T1 value1, T2 value2, T3 value3) builder;

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
  /// Subscribes to three shared StateViewModels identified by each observable's
  /// `shareKey`, passing their current states to `builder` as `value1`, `value2`,
  /// and `value3`.
  @override
  Widget build(BuildContext context) {
    // Rebuilds when any view model's state changes; latest values
    // are passed to `builder`.
    return widget.builder(
      watchCachedViewModel<_ObserveDataViewModel<T1>>(
        key: widget.observable1.shareKey,
      ).state,
      watchCachedViewModel<_ObserveDataViewModel<T2>>(
        key: widget.observable2.shareKey,
      ).state,
      watchCachedViewModel<_ObserveDataViewModel<T3>>(
        key: widget.observable3.shareKey,
      ).state,
    );
  }
}
