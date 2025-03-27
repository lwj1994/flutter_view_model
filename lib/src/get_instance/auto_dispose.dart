// @author luwenjie on 2025/3/25 16:24:32

import 'package:uuid/v4.dart';
import 'package:view_model/src/log.dart';

import 'manager.dart';
import 'store.dart';

class AutoDisposeInstanceController {
  final List<InstanceNotifier> _instanceNotifiers = List.empty(growable: true);
  final watchId = const UuidV4().generate();
  final Function() onRecreate;
  final Map<Object, bool> _notifierListeners = {};

  AutoDisposeInstanceController({required this.onRecreate});

  T getInstance<T>({
    String? key,
    T Function()? factory,
  }) {
    final notifier = instanceManager.getNotifier(
      key: key,
      factory: factory,
      watchId: watchId,
    );
    if (_notifierListeners[notifier] != true) {
      _notifierListeners[notifier] = true;
      _instanceNotifiers.add(notifier);
      notifier.addListener(() {
        switch (notifier.action) {
          case null:
            break;
          case InstanceAction.dispose:
            break;
          case InstanceAction.recreate:
            viewModelLog("$T $key recreate call $watchId refresh");
            onRecreate.call();
            break;
        }
      });
    }
    return notifier.instance;
  }

  Future<void> dispose() async {
    for (var e in _instanceNotifiers) {
      e.removeWatcher(watchId);
    }
    _instanceNotifiers.clear();
  }
}

abstract class InstanceDispose {
  void dispose();
}
