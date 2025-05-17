// @author luwenjie on 2025/3/25 16:24:32

import 'package:uuid/v4.dart';

import 'manager.dart';
import 'store.dart';

class AutoDisposeInstanceController {
  final List<InstanceHandle> _instanceNotifiers = List.empty(growable: true);
  final Function() onRecreate;
  final Map<Object, bool> _notifierListeners = {};

  final String watcherName;

  AutoDisposeInstanceController({
    required this.onRecreate,
    required this.watcherName,
  });

  final _uuid = const UuidV4().generate();

  String get _watchId => "$watcherName:$_uuid";

  T getInstance<T>({
    InstanceFactory<T>? factory,
  }) {
    if (T == dynamic) {
      throw StateError("T must extends ViewModel");
    }
    factory = (factory ?? InstanceFactory<T>()).copyWith(
      watchId: _watchId,
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

  void recycle(Object instance) {
    _instanceNotifiers.removeWhere((e) {
      if (e.instance == instance) {
        e.recycle();
        return true;
      } else {
        return false;
      }
    });
  }

  Future<void> dispose() async {
    for (var e in _instanceNotifiers) {
      e.removeWatcher(_watchId);
    }
    _instanceNotifiers.clear();
  }
}
