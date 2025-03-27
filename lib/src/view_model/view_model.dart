// @author luwenjie on 2025/3/25 17:00:38

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:view_model/src/get_instance/auto_dispose.dart';
import 'package:view_model/src/log.dart';

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

  @protected
  void addDispose(Function() block) async {
    _autoDisposeController.addDispose(block);
  }

  final cacheLimit = 1;

  bool _isDisposed = false;

  bool get isDisposed => _isDisposed;

  ViewModel({required T state}) {
    _store = ViewModelStateStore(
      initialState: state,
    );
  }

  @protected
  void setState(FutureOr<T> Function(T state) reducer) {
    _store.set(reducer);
  }

  T? get previousState {
    return _store.previousState;
  }

  T get state {
    return _store.state;
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
