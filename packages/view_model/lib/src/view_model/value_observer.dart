// ignore_for_file: deprecated_member_use_from_same_package

import 'package:flutter/widgets.dart';
import 'package:view_model/src/get_instance/manager.dart';
import 'package:view_model/src/get_instance/store.dart';
import 'package:view_model/src/view_model/view_model.dart';
import 'package:view_model/src/view_model/widget_mixin/stateful_extension.dart';

/// @nodoc
@Deprecated(
  'Use ValueNotifier with ValueListenableBuilder for widget-local state, '
  'or StateViewModel with ViewModelSpec for managed state. '
  'Scheduled for removal in 2.0.0.',
)
class ObservableValue<T> {
  final Object shareKey;

  final T initialValue;

  T get value {
    return _ensureViewModel().state;
  }

  _ObserveDataViewModel<T>? _vm;

  set value(T newValue) {
    // ignore: invalid_use_of_protected_member
    _ensureViewModel().setState(newValue);
  }

  ObservableValue(this.initialValue, {Object? shareKey})
      : this.shareKey = shareKey ?? Object() {
    _ensureViewModel();
  }

  _ObserveDataViewModel<T> _ensureViewModel() {
    final cached = _vm;
    if (cached != null && !cached.isDisposed) {
      return cached;
    }

    final created = instanceManager.get<_ObserveDataViewModel<T>>(
      factory: InstanceFactory(
        builder: () {
          return _ObserveDataViewModelFactory<T>(
            data: initialValue,
            shareKey: shareKey,
          ).build();
        },
        arg: InstanceArg(key: shareKey),
      ),
    );
    _vm = created;
    return created;
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

/// @nodoc
@Deprecated(
  'Use ValueListenableBuilder for widget-local state, or StateViewModel '
  'with ViewModelSpec for managed state. Scheduled for removal in 2.0.0.',
)
class ObserverBuilder<T> extends StatefulWidget {
  final ObservableValue<T> observable;

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
  @override
  void initState() {
    super.initState();
    widget.observable._ensureViewModel();
  }

  @override
  void didUpdateWidget(covariant ObserverBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    widget.observable._ensureViewModel();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(
      viewModelBinding
          .watchCached<_ObserveDataViewModel<T>>(
            key: widget.observable.shareKey,
          )
          .state,
    );
  }
}

/// @nodoc
@Deprecated(
  'Use ValueListenableBuilder for widget-local state, or one StateViewModel '
  'containing both values. Scheduled for removal in 2.0.0.',
)
class ObserverBuilder2<T1, T2> extends StatefulWidget {
  final ObservableValue<T1> observable1;
  final ObservableValue<T2> observable2;

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
  @override
  void initState() {
    super.initState();
    widget.observable1._ensureViewModel();
    widget.observable2._ensureViewModel();
  }

  @override
  void didUpdateWidget(covariant ObserverBuilder2<T1, T2> oldWidget) {
    super.didUpdateWidget(oldWidget);
    widget.observable1._ensureViewModel();
    widget.observable2._ensureViewModel();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(
      viewModelBinding
          .watchCached<_ObserveDataViewModel<T1>>(
            key: widget.observable1.shareKey,
          )
          .state,
      viewModelBinding
          .watchCached<_ObserveDataViewModel<T2>>(
            key: widget.observable2.shareKey,
          )
          .state,
    );
  }
}

/// @nodoc
@Deprecated(
  'Use ValueListenableBuilder for widget-local state, or one StateViewModel '
  'containing all values. Scheduled for removal in 2.0.0.',
)
class ObserverBuilder3<T1, T2, T3> extends StatefulWidget {
  final ObservableValue<T1> observable1;
  final ObservableValue<T2> observable2;
  final ObservableValue<T3> observable3;

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
  @override
  void initState() {
    super.initState();
    widget.observable1._ensureViewModel();
    widget.observable2._ensureViewModel();
    widget.observable3._ensureViewModel();
  }

  @override
  void didUpdateWidget(covariant ObserverBuilder3<T1, T2, T3> oldWidget) {
    super.didUpdateWidget(oldWidget);
    widget.observable1._ensureViewModel();
    widget.observable2._ensureViewModel();
    widget.observable3._ensureViewModel();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(
      viewModelBinding
          .watchCached<_ObserveDataViewModel<T1>>(
            key: widget.observable1.shareKey,
          )
          .state,
      viewModelBinding
          .watchCached<_ObserveDataViewModel<T2>>(
            key: widget.observable2.shareKey,
          )
          .state,
      viewModelBinding
          .watchCached<_ObserveDataViewModel<T3>>(
            key: widget.observable3.shareKey,
          )
          .state,
    );
  }
}
