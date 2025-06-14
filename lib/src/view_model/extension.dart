// @author luwenjie on 2025/3/25 17:24:31

import 'package:flutter/cupertino.dart';
import 'package:uuid/v4.dart';
import 'package:view_model/src/get_instance/auto_dispose.dart';
import 'package:view_model/src/get_instance/manager.dart';
import 'package:view_model/src/get_instance/store.dart';
import 'package:view_model/src/view_model/view_model.dart';

mixin ViewModelStateMixin<T extends StatefulWidget> on State<T> {
  late final _instanceController = AutoDisposeInstanceController(
    onRecreate: () {
      setState(() {});
    },
    watcherName: viewModelWatcherName(),
  );
  final Map<ViewModel, bool> _stateListeners = {};

  final _defaultViewModelKey = const UuidV4().generate();
  final List<Function()> _disposes = [];
  bool _dispose = false;

  /// add watcherName. it is useful for debug
  String viewModelWatcherName() =>
      ViewModel.config.logEnable ? "$runtimeType" : "";

  @override
  @mustCallSuper
  void initState() {
    super.initState();
  }

  /// trigger vm.dispose and remove it from cache
  void recycleViewModel<VM extends ViewModel>(VM vm) {
    _instanceController.recycle(vm);
    setState(() {});
  }

  /// get existing viewModel by [key], or throw error
  /// if listen == true, [ViewModel] trigger rebuilding automatically.
  VM _requireExistingViewModel<VM extends ViewModel>({
    bool listen = true,
    InstanceArg arg = const InstanceArg(),
  }) {
    final res = _instanceController.getInstance<VM>(
      factory: InstanceFactory(
        arg: arg,
      ),
    );

    if (listen) {
      _addListener(res);
    }
    return res;
  }

  /// [key] ViewModelFactory.Key
  /// [tag] ViewModelFactory.Tag
  /// [factory] ViewModelFactory to create ViewModel.
  /// 1. if [key] is not null, it will find existing ViewModel by key first.
  /// 2. if has [factory] and not found by [key], it will create a new ViewModel by [factory].
  /// 3. if [factory] is null, and [tag] is not null, it will find existing ViewModel by tag.
  /// 4. if all is null, it will find newly created ViewModel from cache.
  ///
  /// if not found will throw [StateError]
  ///
  /// watchViewModel will trigger to rebuild the widget when ViewModel state changed.
  ///
  /// `watchViewModel` and `readViewModel` will bind ViewModel, when no one bind viewModel, viewModel will be disposed automatically
  VM watchViewModel<VM extends ViewModel>({
    ViewModelFactory<VM>? factory,
    String? key,
    Object? tag,
  }) =>
      _tryGetViewModel<VM>(
        factory: factory,
        arg: InstanceArg(
          key: key,
          tag: tag,
        ),
        listen: true,
      );

  /// [key] ViewModelFactory.Key
  /// [tag] ViewModelFactory.Tag
  /// [factory] ViewModelFactory to create ViewModel.
  /// 1. if [key] is not null, it will find existing ViewModel by key first.
  /// 2. if has [factory] and not found by [key], it will create a new ViewModel by [factory].
  /// 3. if [factory] is null, and [tag] is not null, it will find existing ViewModel by tag.
  /// 4. if all is null, it will find newly created ViewModel from cache.
  ///
  /// if not found will throw [StateError]
  ///
  /// readViewModel just read the ViewModel without rebuilding the widget when ViewModel state changed.
  /// `watchViewModel` and `readViewModel` will bind ViewModel, when no one bind viewModel, viewModel will be disposed automatically
  VM readViewModel<VM extends ViewModel>({
    ViewModelFactory<VM>? factory,
    String? key,
    Object? tag,
  }) =>
      _tryGetViewModel<VM>(
        factory: factory,
        arg: InstanceArg(
          key: key,
          tag: tag,
        ),
        listen: false,
      );

  VM _tryGetViewModel<VM extends ViewModel>({
    ViewModelFactory<VM>? factory,
    InstanceArg arg = const InstanceArg(),
    bool listen = true,
  }) {
    if (VM == ViewModel || VM == dynamic) {
      throw StateError("VM must extends ViewModel");
    }
    // find key first to reuse
    if (arg.key != null) {
      try {
        return _requireExistingViewModel<VM>(
          arg: InstanceArg(
            key: arg.key,
          ),
          listen: listen,
        );
      } catch (e) {
        // rethrow if factory is null and tag is null
        if (factory == null && arg.tag == null) {
          rethrow;
        }
      }
    }

    // factory
    if (factory != null) {
      return _createViewModel<VM>(
        factory: factory,
        listen: listen,
      );
    }

    // fallback to find newly created by tag
    return _requireExistingViewModel<VM>(
        arg: InstanceArg(
          tag: arg.tag,
        ),
        listen: listen);
  }

  /// if listen == true, [ViewModel] trigger rebuilding automatically.
  VM _createViewModel<VM extends ViewModel>({
    required ViewModelFactory<VM> factory,
    bool listen = true,
  }) {
    if (_dispose) {
      throw StateError("state is disposed");
    }
    String key = factory.key() ?? _defaultViewModelKey;
    final tag = factory.getTag();
    final res = _instanceController.getInstance<VM>(
      factory: InstanceFactory<VM>(
        arg: InstanceArg(
          key: key,
          tag: tag,
        ),
        builder: factory.build,
      ),
    );
    if (listen) {
      _addListener(res);
    }
    return res;
  }

  void _addListener(ViewModel res) {
    if (_stateListeners[res] != true) {
      _stateListeners[res] = true;
      _disposes.add(res.listen(onChanged: () async {
        if (_dispose) return;
        while (!context.mounted) {
          await Future.delayed(Duration.zero);
          if (_dispose) return;
        }
        setState(() {});
      }));
    }
  }

  VM? maybeWatchViewModel<VM extends ViewModel>({
    ViewModelFactory<VM>? factory,
    String? key,
    Object? tag,
  }) {
    try {
      return watchViewModel(
        factory: factory,
        key: key,
        tag: tag,
      );
    } catch (e) {
      return null;
    }
  }

  VM? maybeReadViewModel<VM extends ViewModel>({
    ViewModelFactory<VM>? factory,
    String? key,
    Object? tag,
  }) {
    try {
      return readViewModel(
        factory: factory,
        key: key,
        tag: tag,
      );
    } catch (e) {
      return null;
    }
  }

  @override
  @mustCallSuper
  void dispose() {
    _dispose = true;
    _stateListeners.clear();
    _instanceController.dispose();
    for (var e in _disposes) {
      e.call();
    }
    super.dispose();
  }
}
