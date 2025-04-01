// @author luwenjie on 2025/3/25 17:00:38

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:uuid/v4.dart';
import 'package:view_model/src/get_instance/manager.dart';
import 'package:view_model/src/get_instance/store.dart';
import 'package:view_model/src/log.dart';
import 'package:view_model/src/view_model/extension.dart';

import 'state_store.dart';

class ViewModel<T> implements InstanceLifeCycle {
  static bool logEnable = false;

  static listenViewModelLifecycle() {
    instanceManager;
  }

  final _autoDisposeController = AutoDisposeController();
  late final ViewModelStateStore<T> _store;

  Function() listen(Function(T state) block) {
    final s = _store.asyncStateStream.listen((event) {
      if (_isDisposed) return;
      switch (event) {
        case AsyncLoading<T>():
          break;
        case AsyncSuccess<T>():
          if (event.changed) {
            block.call(event.state as T);
          }
          break;
        case AsyncError<T>():
          break;
      }
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

  /// provide for external use
  T get state {
    return _store.state;
  }

  /// wait executing state complete
  Future<T> get idleState async {
    while (_store.executingReducer != null) {
      await Future.delayed(Duration.zero);
    }
    return state;
  }

  AsyncState<T> get asyncState {
    return _store.asyncState;
  }

  void dispose() {
    _isDisposed = true;
    _autoDisposeController.dispose();
    _store.dispose();
  }

  @override
  void onCreate(String key, String? watchId) {
    viewModelLog(
        "${this.runtimeType}<${T}>(key=$key,watchId=$watchId) onCreate");
  }

  @protected
  @override
  void onDispose() {
    viewModelLog("${this.runtimeType}<${T}> onDispose");
    dispose();
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
