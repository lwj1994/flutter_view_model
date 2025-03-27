// @author luwenjie on 2025/3/25 17:24:31

import 'package:flutter/cupertino.dart';
import 'package:uuid/v4.dart';
import 'package:view_model/src/get_instance/auto_dispose.dart';
import 'package:view_model/src/get_instance/manager.dart';
import 'package:view_model/src/view_model/view_model.dart';

mixin ViewModelStateMixin<T extends StatefulWidget> on State<T> {
  final instanceController = AutoDisposeInstanceController();
  final Map<ViewModel, bool> _stateListeners = {};

  final _defaultViewModelKey = const UuidV4().generate();

  bool _init = false;
  bool _dispose = false;

  @override
  @mustCallSuper
  void initState() {
    super.initState();
    _init = true;
  }

  void refreshViewModel<VM extends ViewModel>(VM vm) {
    instanceManager.recreate(vm);
    setState(() {});
  }

  VM getViewModel<VM extends ViewModel>({
    String? key,
    VM Function()? factory,
  }) {
    if (_dispose) {
      throw StateError("state is disposed");
    }
    key ??= _defaultViewModelKey;
    final res = instanceController.getInstance<VM>(
      factory: factory,
      key: key,
    );
    if (_stateListeners[res] != true) {
      res.listen((state) async {
        if (_dispose) return;
        while (!context.mounted) {
          await Future.delayed(Duration(milliseconds: 50));
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
    instanceController.dispose();
    super.dispose();
  }
}
