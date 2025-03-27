// @author luwenjie on 2025/3/25 16:24:32

import 'package:uuid/v4.dart';

import 'manager.dart';
import 'store.dart';

class AutoDisposeInstanceController {
  final List<InstanceNotifier> _instanceNotifiers = List.empty(growable: true);
  final watchId = const UuidV4().generate();

  T getInstance<T>({
    String? key,
    T Function()? factory,
  }) {
    final notifier = instanceManager.getNotifier(
      key: key,
      factory: factory,
      watchId: watchId,
    );
    _instanceNotifiers.add(notifier);
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
