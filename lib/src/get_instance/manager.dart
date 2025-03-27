// @author luwenjie on 2025/3/25 12:23:33

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
    required InstanceFactory<T> factory,
  }) {
    return _getStore<T>()
        .getNotifier(
          factory: factory,
        )
        .instance;
  }

  InstanceNotifier getNotifier<T>({
    required InstanceFactory<T> factory,
  }) {
    return _getStore<T>().getNotifier(
      factory: factory,
    );
  }
}

class InstanceFactory<T> {
  final T Function()? builder;
  final String? key;
  final String? watchId;

  InstanceFactory({
    this.builder,
    this.key,
    this.watchId,
  });

  InstanceFactory copyWith({
    T Function()? factory,
    String? key,
    String? watchId,
  }) {
    return InstanceFactory(
      builder: factory ?? this.builder,
      key: key ?? this.key,
      watchId: watchId ?? this.watchId,
    );
  }

  @override
  String toString() {
    return '$T InstanceFactory{factory: $builder, key: $key, watchId: $watchId}';
  }
}
