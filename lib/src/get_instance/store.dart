// @author luwenjie on 2025/3/25 12:14:48

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:uuid/v4.dart';
import 'package:view_model/src/log.dart';

import 'manager.dart';

class Store<T> {
  final _streamController = StreamController<InstanceHandle<T>>.broadcast();
  final Map<String, InstanceHandle<T>> _instances = {};

  /// find newly instance sort by createTime desc
  InstanceHandle<T>? findNewlyInstance() {
    if (_instances.isEmpty) return null;
    final l = _instances.values.toList();
    l.sort((InstanceHandle<T> a, InstanceHandle<T> b) {
      // desc
      return b.index.compareTo(a.index);
    });
    return l.firstOrNull;
  }

  void _listenDispose(InstanceHandle<T> notifier) {
    void onNotify() {
      switch (notifier.action) {
        case null:
          break;
        case InstanceAction.dispose:
          _instances.remove(notifier.key);
          notifier.removeListener(onNotify);
          break;
        case InstanceAction.recreate:
          break;
      }
    }

    notifier.addListener(onNotify);
  }

  InstanceHandle<T> getNotifier({required InstanceFactory<T> factory}) {
    final realKey = factory.key ?? const UuidV4().generate();
    final watchId = factory.watchId;

    // cache
    if (_instances.containsKey(realKey) && _instances[realKey] != null) {
      final notifier = _instances[realKey]!;
      final newWatcher =
          watchId != null && !notifier.watchIds.contains(watchId);
      if (newWatcher) {
        notifier.addNewWatcher(watchId);
      }
      return notifier;
    }

    if (factory.builder == null) {
      throw StateError("factory == null and cache is null");
    }

    // create new instance
    final instance = factory.builder!();

    int maxIndex = -1;
    for (var e in _instances.values) {
      if (e.index > maxIndex) {
        maxIndex = e.index;
      }
    }
    final create = InstanceHandle<T>(
      instance: instance,
      key: realKey,
      factory: factory.builder!,
      initWatchId: factory.watchId,
      index: maxIndex + 1,
    );
    _instances[realKey] = create;
    _streamController.add(create);
    _listenDispose(create);
    return create;
  }

  T recreate(T t) {
    final find = _instances.values.where((e) => e.instance == t).first;
    return find.recreate();
  }
}

class InstanceHandle<T> with ChangeNotifier {
  final String key;
  final String? initWatchId;
  final List<String> watchIds = List.empty(growable: true);
  final T Function() factory;
  final int index;

  T get instance => _instance!;

  late T? _instance;

  InstanceHandle({
    required T instance,
    required this.key,
    this.initWatchId,
    required this.index,
    required this.factory,
  }) : _instance = instance {
    onCreate(key, initWatchId);
  }

  void _addWatcher(String? id) {
    if (watchIds.contains(id) || id == null) return;
    watchIds.add(id);
    if (_instance is InstanceLifeCycle) {
      (_instance as InstanceLifeCycle).onAddWatcher(key, id);
    }
  }

  void removeWatcher(String id) {
    if (watchIds.remove(id)) {
      if (_instance is InstanceLifeCycle) {
        (_instance as InstanceLifeCycle).onRemoveWatcher(key, id);
      }
    }
    if (watchIds.isEmpty) {
      recycle();
    }
  }

  InstanceAction? _action;

  InstanceAction? get action => _action;

  void recycle() {
    _action = InstanceAction.dispose;
    notifyListeners();
    onDispose();
  }

  T recreate() {
    onDispose();
    _instance = factory.call();
    onCreate(key, initWatchId);
    _action = InstanceAction.recreate;
    notifyListeners();
    return instance;
  }

  @override
  String toString() {
    return "InstanceHandle<$T>(index=$index, key=$key, initWatchId=$initWatchId, watchIds=$watchIds)";
  }

  void onCreate(String key, String? watchId) {
    if (_instance is InstanceLifeCycle) {
      (_instance as InstanceLifeCycle).onCreate(key);
    }
    _addWatcher(watchId);
  }

  void addNewWatcher(String id) {
    _addWatcher(id);
  }

  void _tryCallInstanceDispose() {
    if (_instance is InstanceLifeCycle) {
      try {
        (_instance as InstanceLifeCycle).onDispose(key);
      } catch (e) {
        viewModelLog("${_instance.runtimeType} onDispose error $e");
      }
    }
  }

  void onDispose() {
    _tryCallInstanceDispose();
    _instance = null;
    watchIds.clear();
    _instance = null;
  }
}

enum InstanceAction {
  dispose,
  recreate,
}

abstract interface class InstanceLifeCycle {
  void onCreate(String key);

  void onAddWatcher(String key, String newWatchId);

  void onRemoveWatcher(String key, String removedWatchId);

  void onDispose(String key);
}
