// @author luwenjie on 2025/3/25 12:14:48

import 'package:flutter/cupertino.dart';
import 'package:uuid/v4.dart';
import 'package:view_model/src/log.dart';

import 'auto_dispose.dart';

class Store<T> {
  final Map<String, InstanceNotifier<T>> _instances = {};
  final Map<String, List<String>> _watchers = {};

  void _listenDispose(InstanceNotifier<T> notifier) {
    void onNotify() {
      switch (notifier.action) {
        case null:
          break;
        case InstanceAction.dispose:
          viewModelLog("remove $T ${notifier.key}");
          _instances.remove(notifier.key);
          _watchers.remove(notifier.key);
          notifier.tryCallInstanceDispose();
          notifier.removeListener(onNotify);
          notifier.clear();
          break;
        case InstanceAction.recreate:
          break;
      }
    }

    notifier.addListener(onNotify);
  }

  List<String> _getWaters(String key) {
    List<String>? s = _watchers[key];
    s ??= List.empty();
    _watchers[key] = s;
    return s;
  }

  /// 根据 key 和工厂函数创建并存储实例
  InstanceNotifier<T> getNotifier({
    String? key,
    T Function()? factory,
    Object? extra,
    String? watchId,
  }) {
    final realKey = key ?? const UuidV4().generate();
    if (watchId != null) {
      _watchers[realKey] = _getWaters(realKey).toList()..add(watchId);
    }
    if (_instances.containsKey(realKey) && _instances[realKey] != null) {
      viewModelLog("hit cache $T $realKey");
      final notifier = _instances[realKey]!;
      if (watchId != null) {
        notifier.addWatcher(watchId);
        viewModelLog(
            "$T $realKey add watcher ${watchId}, all ${_watchers[realKey]}");
      }

      return notifier;
    }

    if (factory == null) {
      throw StateError("factory == null and cache is null");
    }

    // new create
    final instance = factory();
    final create = InstanceNotifier(
      instance: instance,
      key: realKey,
      extra: extra,
      factory: factory,
    );
    if (watchId != null) {
      create.addWatcher(watchId);
    }
    _instances[realKey] = create;
    viewModelLog("create $T $realKey watcher $watchId");
    _listenDispose(create);
    return create;
  }

  T recreate(T t) {
    final find = _instances.values.where((e) => e.instance == t).first;
    return find.recreate();
  }
}

class InstanceNotifier<T> with ChangeNotifier {
  final String key;
  final List<String> watchIds = List.empty(growable: true);
  final Object? extra;
  final T Function() factory;

  T get instance => _instance!;

  late T? _instance;

  InstanceNotifier({
    required T instance,
    required this.key,
    this.extra,
    required this.factory,
  }) : _instance = instance;

  void addWatcher(String id) {
    if (watchIds.contains(id)) return;
    watchIds.add(id);
  }

  void removeWatcher(String id) {
    if (watchIds.remove(id)) {
      viewModelLog("$T removeWatcher $id, $watchIds");
    }
    if (watchIds.isEmpty) {
      recycle();
    }
  }

  InstanceAction? _action;

  InstanceAction? get action => _action;

  @protected
  @override
  void dispose() {
    super.dispose();
    _instance = null;
  }

  void recycle() {
    _action = InstanceAction.dispose;
    notifyListeners();
  }

  void tryCallInstanceDispose() {
    if (_instance is InstanceDispose) {
      (_instance as InstanceDispose).dispose();
    }
  }

  T recreate() {
    tryCallInstanceDispose();
    _instance = factory.call();
    _action = InstanceAction.recreate;
    notifyListeners();
    return instance;
  }

  void clear() {
    watchIds.clear();
    _instance = null;
  }
}

enum InstanceAction {
  dispose,
  recreate,
}
