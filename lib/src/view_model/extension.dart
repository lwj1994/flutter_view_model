// @author luwenjie on 2025/3/25 17:24:31

import 'package:flutter/cupertino.dart';
import 'package:uuid/v4.dart';
import 'package:view_model/src/get_instance/auto_dispose.dart';
import 'package:view_model/src/get_instance/manager.dart';
import 'package:view_model/src/view_model/view_model.dart';

mixin ViewModelStateMixin<T extends StatefulWidget> on State<T> {
  late final _instanceController =
      AutoDisposeInstanceController(onRecreate: () {
    setState(() {});
  });
  final Map<ViewModel, bool> _stateListeners = {};

  final _defaultViewModelKey = const UuidV4().generate();
  final List<Function()> _disposes = [];
  bool _dispose = false;

  @override
  @mustCallSuper
  void initState() {
    super.initState();
  }

  void refreshViewModel<VM extends ViewModel>(VM vm) {
    instanceManager.recreate(vm);
    setState(() {});
  }

  void listenViewModelStateChanged<VM extends ViewModel<S>, S>(VM vm,
      {required Function(S? p, S n) onChange}) {
    _disposes.add(vm.listen((s) {
      onChange(vm.previousState, s);
    }));
  }

  VM getViewModel<VM extends ViewModel>(
      {required ViewModelFactory<VM> factory}) {
    if (_dispose) {
      throw StateError("state is disposed");
    }
    String key = factory.key() ?? _defaultViewModelKey;
    final res = _instanceController.getInstance<VM>(
      factory: InstanceFactory(
        key: key,
        builder: () => factory.build(),
      ),
    );
    if (_stateListeners[res] != true) {
      res.listen((state) async {
        if (_dispose) return;
        while (!context.mounted) {
          await Future.delayed(const Duration(milliseconds: 50));
          if (_dispose) return;
        }
        setState(() {});
      });
    }
    return res;
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
