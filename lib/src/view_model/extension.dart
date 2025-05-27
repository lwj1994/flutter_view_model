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
        //
      }
    }

    // factory
    if (factory != null) {
      return _createViewModel<VM>(
        factory: factory,
        listen: listen,
      );
    }

    // fallback to find newly created
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
