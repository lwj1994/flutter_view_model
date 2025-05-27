// @author luwenjie on 2025/3/25 12:23:33

import 'store.dart';

final instanceManager = InstanceManager._get();

class InstanceManager {
  InstanceManager._();

  T recreate<T>(
    T t, {
    T Function()? builder,
  }) {
    final Store<T> s = _stores[T];
    return s.recreate(
      t,
      builder: builder,
    );
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
    if (T == dynamic) {
      throw StateError("T is dynamic");
    }
    if (factory == null || factory.isEmpty()) {
      final watchId = factory?.arg.watchId;
      final tag = factory?.arg.tag;
      // find newly T instance
      final find = _getStore<T>().findNewlyInstance(
        tag: tag,
      );
      if (find == null) {
        throw StateError("no $T instance found");
      }

      // if watchId is not null, add watcher
      if (watchId != null) {
        final factory = InstanceFactory<T>(
            arg: InstanceArg(
          watchId: watchId,
          key: find.arg.key,
          tag: find.arg.tag,
        ));
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
  final InstanceArg arg;

  bool isEmpty() {
    return builder == null && arg.key == null;
  }

  factory InstanceFactory.watch({required String watchId}) {
    return InstanceFactory(
      arg: InstanceArg(
        watchId: watchId,
      ),
    );
  }

  InstanceFactory({
    this.builder,
    this.arg = const InstanceArg(),
  });

  InstanceFactory<T> copyWith({
    T Function()? factory,
    InstanceArg? arg,
  }) {
    return InstanceFactory<T>(
      builder: factory ?? this.builder,
      arg: arg ?? this.arg,
    );
  }

  @override
  String toString() {
    return '$T InstanceFactory{arg: $arg}';
  }
}
