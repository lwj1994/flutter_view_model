// @author luwenjie on 2025/3/25 17:00:38

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:uuid/v4.dart';
import 'package:view_model/src/get_instance/auto_dispose.dart';
import 'package:view_model/src/log.dart';
import 'package:view_model/src/view_model/extension.dart';

import 'state_store.dart';

class ViewModel<T> implements InstanceDispose {
  final _autoDisposeController = AutoDisposeController();
  late final ViewModelStateStore<T> _store;

  Function() listen(Function(T state) block) {
    final s = _store.stateStream.listen((event) {
      if (_isDisposed) return;
      block.call(event);
    });
    return s.cancel;
  }

  Function() listenAsync(Function(AsyncState<T> state) block) {
    final s = _store.asyncStateStream.listen((event) {
      if (_isDisposed) return;
      block.call(event);
    });
    return s.cancel;
  }

  @protected
  void addDispose(Function() block) async {
    _autoDisposeController.addDispose(block);
  }

  bool _isDisposed = false;

  late final T initState;

  bool get isDisposed => _isDisposed;

  ViewModel({required T state}) {
    initState = state;
    _store = ViewModelStateStore(
      initialState: state,
    );
  }

  @protected
  void setState(
    FutureOr<T> Function(T state) reducer, {
    Object? tag,
  }) {
    _store.set(Reducer(
      builder: reducer,
      tag: tag,
    ));
  }

  T? get previousState {
    return _store.previousState;
  }

  T get state {
    return _store.state;
  }

  AsyncState<T> get asyncState {
    return _store.asyncState;
  }

  @override
  void dispose() {
    _isDisposed = true;
    _autoDisposeController.dispose();
    _store.dispose();
  }
}

class AutoDisposeController {
  final _disposeSet = <Function()?>[];

  void addDispose(Function() block) async {
    _disposeSet.add(block);
  }

  void dispose() {
    for (var element in _disposeSet) {
      try {
        element?.call();
      } catch (e) {
        viewModelLog("AutoDisposeMixin error on $e");
      }
    }
  }
}

mixin ViewModelFactory<T> {
  static final _uniqueId = const UuidV4().generate();

  /// if you want to set your key. unique() must be false
  /// uniqueId dependency on T. so T's name must unique
  String? key() => unique() ? _uniqueId : null;

  T build();

  /// if true, key will auto set a unique id
  bool unique() => false;
}
