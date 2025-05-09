// @author luwenjie on 2025/3/25 17:00:38

import 'package:flutter/cupertino.dart';
import 'package:uuid/v4.dart';
import 'package:view_model/src/get_instance/store.dart';
import 'package:view_model/src/log.dart';
import 'package:view_model/src/view_model/config.dart';

import 'state_store.dart';

abstract class ViewModel<T> implements InstanceLifeCycle {
  static ViewModelConfig _config = ViewModelConfig();

  static ViewModelConfig get config => _config;

  static void initConfig(ViewModelConfig config) {
    _config = config;
  }

  final _autoDisposeController = AutoDisposeController();
  late final ViewModelStateStore<T> _store;

  Function() listen({required Function(T? previous, T state) onChanged}) {
    final s = _store.stateStream.listen((event) {
      if (_isDisposed) return;
      onChanged.call(event.p, event.n);
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
  void notifyListeners() {
    _store.notifyListeners();
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

  void dispose() {
    _isDisposed = true;
    _autoDisposeController.dispose();
    _store.dispose();
  }

  @override
  void onCreate(String key, String? watchId) {
    viewModelLog("$runtimeType<$T>(key=$key,watchId=$watchId) onCreate");
  }

  @protected
  @override
  void onDispose() {
    viewModelLog("$runtimeType<$T> onDispose");
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
