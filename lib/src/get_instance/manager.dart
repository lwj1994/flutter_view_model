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

  /// if null throw error
  T get<T>({
    InstanceFactory<T>? factory,
  }) {
    return getNotifier(factory: factory).instance;
  }

  InstanceHandle<T> getNotifier<T>({
    InstanceFactory<T>? factory,
  }) {
    if (factory == null || factory.isEmpty()) {
      final watchId = factory?.watchId;
      // find newly T instance
      final find = _getStore<T>().findNewlyInstance();
      if (find == null) {
        throw StateError("no $T instance found");
      }

      // if watchId is not null, add watcher
      if (watchId != null) {
        final factory = InstanceFactory<T>(
          watchId: watchId,
          key: find.key,
        );
        return _getStore<T>().getNotifier(factory: factory);
      } else {
        return find;
      }
    } else {
      return _getStore<T>().getNotifier(
        factory: factory,
      );
    }
  }
}

class InstanceFactory<T> {
  final T Function()? builder;
  final String? key;
  final String? watchId;

  bool isEmpty() {
    return builder == null && key == null;
  }

  factory InstanceFactory.watch({required String watchId}) {
    return InstanceFactory(
      watchId: watchId,
    );
  }

  InstanceFactory({
    this.builder,
    this.key,
    this.watchId,
  });

  InstanceFactory<T> copyWith({
    T Function()? factory,
    String? key,
    String? watchId,
  }) {
    return InstanceFactory<T>(
      builder: factory ?? this.builder,
      key: key ?? this.key,
      watchId: watchId ?? this.watchId,
    );
  }

  @override
  String toString() {
    return '$T InstanceFactory{key: $key, watchId: $watchId}';
  }
}
