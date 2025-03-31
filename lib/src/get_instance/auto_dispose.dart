// @author luwenjie on 2025/3/25 16:24:32

import 'package:uuid/v4.dart';
import 'package:view_model/src/log.dart';

import 'manager.dart';
import 'store.dart';

class AutoDisposeInstanceController {
  final List<InstanceHandle> _instanceNotifiers = List.empty(growable: true);
  final watchId = const UuidV4().generate();
  final Function() onRecreate;
  final Map<Object, bool> _notifierListeners = {};

  AutoDisposeInstanceController({required this.onRecreate});

  T getInstance<T>({
    required InstanceFactory<T> factory,
  }) {
    factory = factory.copyWith(
      watchId: watchId,
    );
    final InstanceHandle<T> notifier = instanceManager.getNotifier<T>(
      factory: factory,
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
