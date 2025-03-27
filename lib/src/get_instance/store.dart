// @author luwenjie on 2025/3/25 12:14:48

import 'package:flutter/cupertino.dart';
import 'package:uuid/v4.dart';
import 'package:view_model/src/log.dart';

import 'auto_dispose.dart';
import 'manager.dart';

class Store<T> {
  final Map<String, InstanceNotifier<T>> _instances = {};

  void _listenDispose(InstanceNotifier<T> notifier) {
    void onNotify() {
      switch (notifier.action) {
        case null:
          break;
        case InstanceAction.dispose:
          viewModelLog("remove $T ${notifier.key}");
          _instances.remove(notifier.key);
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

  InstanceNotifier<T> getNotifier({required InstanceFactory<T> factory}) {
    final realKey = factory.key ?? const UuidV4().generate();
    final watchId = factory.watchId;
    if (_instances.containsKey(realKey) && _instances[realKey] != null) {
      final notifier = _instances[realKey]!;
      final newWatcher =
          watchId != null && !notifier.watchIds.contains(watchId);
      if (newWatcher) {
        notifier.addWatcher(watchId);
        viewModelLog(
            "hit cache $T $realKey, watchId $watchId, all ${notifier.watchIds}");
      }
      return notifier;
    }

    if (factory.builder == null) {
      throw StateError("factory == null and cache is null");
    }

    // new create
    final instance = factory.builder!();
    final create = InstanceNotifier<T>(
      instance: instance,
      key: realKey,
      factory: factory.builder!,
    );
    if (watchId != null) {
      create.addWatcher(watchId);
    }
    _instances[realKey] = create;
    viewModelLog("create new $T $realKey, watchId $watchId");
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
  final T Function() factory;

  T get instance => _instance!;

  late T? _instance;

  InstanceNotifier({
    required T instance,
    required this.key,
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
