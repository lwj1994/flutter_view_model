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
  InstanceHandle<T>? findNewlyInstance({
    Object? tag,
  }) {
    if (_instances.isEmpty) return null;
    final l = _instances.values.toList();
    l.sort((InstanceHandle<T> a, InstanceHandle<T> b) {
      // desc
      return b.index.compareTo(a.index);
    });
    if (tag == null) {
      return l.firstOrNull;
    } else {
      for (InstanceHandle<T> instance in l) {
        if (instance.arg.tag == tag) {
          return instance;
        }
      }
      return null;
    }
  }

  void _listenDispose(InstanceHandle<T> notifier) {
    void onNotify() {
      switch (notifier.action) {
        case null:
          break;
        case InstanceAction.dispose:
          _instances.remove(notifier.arg.key);
          notifier.removeListener(onNotify);
          break;
        case InstanceAction.recreate:
          break;
      }
    }

    notifier.addListener(onNotify);
  }

  InstanceHandle<T> getNotifier({required InstanceFactory<T> factory}) {
    final realKey = factory.arg.key ?? const UuidV4().generate();
    final watchId = factory.arg.watchId;
    final arg = factory.arg.copyWith(
      key: realKey,
    );
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
      arg: arg,
      factory: factory.builder!,
      index: maxIndex + 1,
    );
    _instances[realKey] = create;
    _streamController.add(create);
    _listenDispose(create);
    return create;
  }

  T recreate(
    T t, {
    T Function()? builder,
  }) {
    final find = _instances.values.where((e) => e.instance == t).first;
    return find.recreate(builder: builder);
  }
}

class InstanceHandle<T> with ChangeNotifier {
  final InstanceArg arg;
  final List<String> watchIds = List.empty(growable: true);
  final T Function() factory;
  final int index;

  T get instance => _instance!;

  late T? _instance;

  InstanceHandle({
    required T instance,
    required this.arg,
    required this.index,
    required this.factory,
  }) : _instance = instance {
    onCreate(arg);
  }

  void _addWatcher(String? id) {
    if (watchIds.contains(id) || id == null) return;
    watchIds.add(id);
    if (_instance is InstanceLifeCycle) {
      (_instance as InstanceLifeCycle).onAddWatcher(arg, id);
    }
  }

  void removeWatcher(String id) {
    if (watchIds.remove(id)) {
      if (_instance is InstanceLifeCycle) {
        (_instance as InstanceLifeCycle).onRemoveWatcher(arg, id);
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

  T recreate({
    T Function()? builder,
  }) {
    onDispose();
    _instance = (builder?.call()) ?? factory.call();
    onCreate(arg);
    _action = InstanceAction.recreate;
    notifyListeners();
    return instance;
  }

  @override
  String toString() {
    return "InstanceHandle<$T>(index=$index, $arg, watchIds=$watchIds)";
  }

  void onCreate(InstanceArg arg) {
    if (_instance is InstanceLifeCycle) {
      (_instance as InstanceLifeCycle).onCreate(arg);
    }
    _addWatcher(arg.watchId);
  }

  void addNewWatcher(String id) {
    _addWatcher(id);
  }

  void _tryCallInstanceDispose() {
    if (_instance is InstanceLifeCycle) {
      try {
        (_instance as InstanceLifeCycle).onDispose(arg);
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
  void onCreate(InstanceArg arg);

  void onAddWatcher(InstanceArg arg, String newWatchId);

  void onRemoveWatcher(InstanceArg arg, String removedWatchId);

  void onDispose(InstanceArg arg);
}

class InstanceArg {
  final String? key;
  final Object? tag;
  final String? watchId;

//<editor-fold desc="Data Methods">
  const InstanceArg({
    this.key,
    this.tag,
    this.watchId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InstanceArg &&
          runtimeType == other.runtimeType &&
          key == other.key &&
          tag == other.tag &&
          watchId == other.watchId);

  @override
  int get hashCode => key.hashCode ^ tag.hashCode ^ watchId.hashCode;

  @override
  String toString() {
    return 'InstanceArg{' ' key: $key,' ' tag: $tag,' ' watchId: $watchId,' '}';
  }

  InstanceArg copyWith({
    String? key,
    Object? tag,
    String? watchId,
  }) {
    return InstanceArg(
      key: key ?? this.key,
      tag: tag ?? this.tag,
      watchId: watchId ?? this.watchId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'key': key,
      'tag': tag,
      'watchId': watchId,
    };
  }

  factory InstanceArg.fromMap(Map<String, dynamic> map) {
    return InstanceArg(
      key: map['key'] as String,
      tag: map['tag'] as Object,
      watchId: map['watchId'] as String,
    );
  }

//</editor-fold>
}
