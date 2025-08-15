// @author luwenjie on 2025/3/25 17:00:38

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/v4.dart';
import 'package:view_model/src/dependency/dependency_tracker.dart';
import 'package:view_model/src/devtool/devtools_service.dart';
import 'package:view_model/src/get_instance/manager.dart';
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
  late InstanceArg _instanceArg;

  Object? get tag => _instanceArg.tag;

  static bool _initialized = false;
  static bool _initializedDevtool = false;

  static final List<ViewModelLifecycle> _viewModelLifecycles =
      List.empty(growable: true);

  /// read a ViewModel instance by [key] or [tag]. maybe return null.
  static T? maybeRead<T extends ViewModel>({String? key, Object? tag}) {
    try {
      return read(key: key, tag: tag);
    } catch (e) {
      return null;
    }
  }

  /// read a ViewModel instance by [key] or [tag].
  /// [key] ViewModelFactory.Key
  /// [tag] ViewModelFactory.Tag
  /// 1. if [key] is not null, it will find existing ViewModel by key first.
  /// 2. if [tag] is not null, it will find existing ViewModel by tag.
  /// 3. if all is null, it will find newly created ViewModel from cache.
  ///
  /// if not found will throw [StateError]
  static T read<T extends ViewModel>({String? key, Object? tag}) {
    T? vm;

    /// find key firstly
    if (key != null) {
      try {
        vm = instanceManager.get<T>(
          factory: InstanceFactory<T>(
              arg: InstanceArg(
            key: key,
          )),
        );
      } catch (e) {
        //
      }
    }

    // find newly cache
    vm = instanceManager.get<T>(
      factory: InstanceFactory<T>(
          arg: InstanceArg(
        tag: tag,
      )),
    );

    if (vm.isDisposed) {
      throw StateError("$T is disposed");
    }
    return vm;
  }

  static Function() addLifecycle(ViewModelLifecycle lifecycle) {
    _viewModelLifecycles.add(lifecycle);
    return () {
      _viewModelLifecycles.remove(lifecycle);
    };
  }

  static void removeLifecycle(ViewModelLifecycle value) {
    _viewModelLifecycles.remove(value);
  }

  final List<VoidCallback?> _listeners = [];
  static ViewModelConfig _config = ViewModelConfig();

  static ViewModelConfig get config => _config;

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

  /// initialize ViewModel system
  /// [config] configure ViewModel behavior
  /// [lifecycles] add global lifecycles to ViewModel
  static void initialize(
      {ViewModelConfig? config,
      Iterable<ViewModelLifecycle> lifecycles = const []}) {
    if (_initialized) return;
    _initialized = true;
    if (config != null) {
      _config = config;
    }
    _viewModelLifecycles.addAll(lifecycles);
    _initDevtool();
  }

  /// initialize devtool if in debug mode
  static void _initDevtool() {
    if (_initializedDevtool) return;
    _initializedDevtool = true;
    if (kDebugMode) {
      _viewModelLifecycles.add(DependencyTracker.instance);
      DevToolsService.instance.initialize();
    }
  }

  @override
  @protected
  @mustCallSuper
  void onCreate(InstanceArg arg) {
    _initDevtool();
    _instanceArg = arg;
    for (var element in _viewModelLifecycles) {
      element.onCreate(this, arg);
    }
  }

  @protected
  @mustCallSuper
  @override
  void onAddWatcher(InstanceArg arg, String newWatchId) {
    for (var element in _viewModelLifecycles) {
      element.onAddWatcher(this, arg, newWatchId);
    }
  }

  @protected
  @mustCallSuper
  @override
  void onRemoveWatcher(InstanceArg arg, String removedWatchId) {
    for (var element in _viewModelLifecycles) {
      element.onRemoveWatcher(this, arg, removedWatchId);
    }
  }

  @override
  @mustCallSuper
  @protected
  void onDispose(InstanceArg arg) {
    _isDisposed = true;
    _autoDisposeController.dispose();
    dispose();
    for (var element in _viewModelLifecycles) {
      element.onDispose(this, arg);
    }
  }

  @protected
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

  void removeStateListener(Function(T? previous, T state) listener) {
    _stateListeners.remove(listener);
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
    _store.dispose();
    _listeners.clear();
    _stateListeners.clear();
    _streamSubscription.cancel();
    super.dispose();
  }

  @override
  void onCreate(InstanceArg arg) {
    super.onCreate(arg);
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

abstract mixin class ViewModelFactory<T> {
  static final _defaultShareId = const UuidV4().generate();

  /// customs key to share the viewModel instance. this will ignore [autoSharable()]
  /// same key will get same viewModel instance
  ///
  /// ```dart
  /// class MyState extend State<MyWidget> with ViewModelStateMixin{
  ///   MyViewModel _viewModel => watchViewModel(factory: MyViewModelFactory(key: "my_key"));
  /// }
  ///
  String? key() => (singleton()) ? _defaultShareId : null;

  /// set tag for viewModel to flag something.
  /// you can get the tag by [ViewModel.tag].
  /// you can find newly viewModel which has the tag if it exists, or throw [Exception].
  /// ```dart
  /// class MyState extend State<MyWidget> with ViewModelStateMixin{
  ///   MyViewModel _viewModel => watchViewModel(tag: tag)
  /// }
  /// ```
  Object? getTag() => null;

  /// how to build your viewModel instance
  T build();

  /// auto return [_defaultShareId] as [key()] to share the viewModel instance
  /// [T] will only have a instance
  bool singleton() => false;
}

abstract class ViewModelLifecycle {
  void onCreate(ViewModel viewModel, InstanceArg arg) {}

  void onAddWatcher(ViewModel viewModel, InstanceArg arg, String newWatchId) {}

  void onRemoveWatcher(
      ViewModel viewModel, InstanceArg arg, String removedWatchId) {}

  void onDispose(ViewModel viewModel, InstanceArg arg) {}
}

/// A default generic ViewModelFactory for quickly creating ViewModel factories.
class DefaultViewModelFactory<T extends ViewModel> extends ViewModelFactory<T> {
  final T Function() builder;
  late final String? _key;
  late final Object? _tag;
  final bool isSingleton;

  DefaultViewModelFactory({
    required this.builder,
    String? key,
    Object? tag,
    this.isSingleton = false,
  }) {
    _key = key;
    _tag = tag;
  }

  @override
  String? key() {
    if (_key == null) {
      return super.key();
    } else {
      return _key;
    }
  }

  @override
  Object? getTag() => _tag;

  @override
  T build() => builder();

  @override
  bool singleton() => isSingleton;
}
