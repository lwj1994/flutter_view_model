// @author luwenjie on 2025/3/25 17:00:38

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:uuid/v4.dart';
import 'package:view_model/src/get_instance/store.dart';
import 'package:view_model/src/log.dart';
import 'package:view_model/src/view_model/config.dart';

import 'state_store.dart';

/// ViewModel api will override ChangeNotifier api.
class ChangeNotifierViewModel extends ChangeNotifier with ViewModel {
  @override
  void addListener(VoidCallback listener) {
    listen(onChanged: listener);
  }
}

mixin class ViewModel implements InstanceLifeCycle {
  final List<VoidCallback?> _listeners = [];
  static ViewModelConfig _config = ViewModelConfig();
  final _autoDisposeController = AutoDisposeController();
  bool _isDisposed = false;

  bool get isDisposed => _isDisposed;

  bool get hasListeners => _listeners.isNotEmpty;

  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  @protected
  void addDispose(Function() block) async {
    _autoDisposeController.addDispose(block);
  }

  Function() listen({required VoidCallback onChanged}) {
    _listeners.add(onChanged);
    return () {
      _listeners.remove(onChanged);
    };
  }

  void notifyListeners() {
    for (var element in _listeners) {
      try {
        element?.call();
      } catch (e) {
        viewModelLog("error on $e");
      }
    }
  }

  static void initConfig(ViewModelConfig config) {
    _config = config;
  }

  static ViewModelConfig get config => _config;

  @override
  @mustCallSuper
  void onCreate(String key, String? watchId) {}

  /// protect this method
  @override
  @mustCallSuper
  @protected
  void onDispose() {
    _isDisposed = true;
    _autoDisposeController.dispose();
    dispose();
  }

  @mustCallSuper
  void dispose() {}
}

abstract class StateViewModel<T> with ViewModel {
  late final ViewModelStateStore<T> _store;
  final List<Function(T? previous, T state)?> _stateListeners = [];

  Function() listenState({required Function(T? previous, T state) onChanged}) {
    _stateListeners.add(onChanged);
    return () {
      _stateListeners.remove(onChanged);
    };
  }

  late final T initState;
  late final StreamSubscription _streamSubscription;

  StateViewModel({required T state}) {
    initState = state;
    _store = ViewModelStateStore(
      initialState: state,
    );

    _streamSubscription = _store.stateStream.listen((event) async {
      if (_isDisposed) return;
      for (var element in _stateListeners) {
        try {
          element?.call(event.p, event.n);
        } catch (e) {
          //
        }
      }

      for (var element in _listeners) {
        try {
          element?.call();
        } catch (e) {
          //
        }
      }
    });
  }

  @override
  void notifyListeners() {
    if (_isDisposed) {
      viewModelLog("notifyListeners after Disposed");
      return;
    }
    try {
      _store.notifyListeners();
    } catch (e) {
      onError(e);
    }
  }

  @protected
  void setState(T state) {
    if (_isDisposed) {
      viewModelLog("setState after Disposed");
      return;
    }
    try {
      _store.setState(state);
    } catch (e) {
      onError(e);
    }
  }

  @protected
  void onError(dynamic e) {
    viewModelLog("error :$e");
  }

  T? get previousState {
    return _store.previousState;
  }

  /// provide for external use
  T get state {
    return _store.state;
  }

  @mustCallSuper
  @override
  void dispose() {
    viewModelLog("$runtimeType<$T> onDispose");
    _store.dispose();
    _listeners.clear();
    _stateListeners.clear();
    _streamSubscription.cancel();
    super.dispose();
  }

  @override
  void onCreate(String key, String? watchId) {
    super.onCreate(key, watchId);
    viewModelLog("$runtimeType<$T>(key=$key,watchId=$watchId) onCreate");
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
  static final singletonId = const UuidV4().generate();

  /// 如果 [key] 一样，那么获取的就是同一个内存地址的 [T]
  /// 比如 key = "userId"，那么不同 User 会获取的自己的单例
  /// key = null，每次都会调用 [build] 创建新实例
  String? key() => singleton() ? singletonId : null;

  T build();

  /// 便捷的把当前类型 [T] 设置为单例共享
  /// 如果需要共享不同的实例，根据需求去重写 [key]
  /// [key] 的优先级高于 [singleton]
  bool singleton() => false;
}
