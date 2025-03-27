// @author luwenjie on 2025/3/25 12:23:33

import 'package:flutter/cupertino.dart';
import 'store.dart';

final instanceManager = InstanceManager._get();

class InstanceManager {

  InstanceManager._();



  T recreate<T>(T t) {
    final Store<T> s = _stores[T];
    return s.recreate(t);
  }



  factory InstanceManager._get() => _instance;
  static final InstanceManager _instance = InstanceManager._();

  final Map<Type, dynamic> _stores = {};

  /// 获取指定类型的 Store
  Store<T> _getStore<T>() {
    Store<T>? s = _stores[T];
    s ??= Store<T>();
    _stores[T] = s;
    return s;
  }

  T get<T>({
    String? key,
    T Function()? factory,
    Object? extra,
    String? watchId,
  }) {
    return _getStore<T>()
        .getNotifier(
          key: key,
          factory: factory,
          extra: extra,
        )
        .instance;
  }

  InstanceNotifier getNotifier<T>({
    String? key,
    T Function()? factory,
    String? watchId,
  }) {
    return _getStore<T>().getNotifier(
      key: key,
      factory: factory,
      watchId: watchId,
    );
  }
}
