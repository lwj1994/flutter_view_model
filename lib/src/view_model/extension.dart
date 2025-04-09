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

  /// if listen == true, [ViewModel] trigger rebuilding automatically.
  VM getViewModel<VM extends ViewModel>({
    required ViewModelFactory<VM> factory,
    bool listen = true,
  }) {
    if (_dispose) {
      throw StateError("state is disposed");
    }
    String key = factory.key() ?? _defaultViewModelKey;
    final res = _instanceController.getInstance<VM>(
      factory: InstanceFactory<VM>(
        key: key,
        builder: () => factory.build(),
      ),
    );
    if (listen) {
      if (_stateListeners[res] != true) {
        res.listen(onChanged: (p, n) async {
          if (_dispose) return;
          while (!context.mounted) {
            await Future.delayed(Duration.zero);
            if (_dispose) return;
          }
          setState(() {});
        });
      }
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
