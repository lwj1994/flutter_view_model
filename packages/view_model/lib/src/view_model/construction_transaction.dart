library;

import 'package:view_model/src/view_model/state_store.dart';

/// Marker used for the stable private default key of an unkeyed binding scope.
class ViewModelPrivateKey {}

class _ConstructionIdentity {
  const _ConstructionIdentity({
    required this.type,
    required this.key,
    required this.isImplicit,
  });

  final Type type;
  final Object key;
  final bool isImplicit;

  String get description => isImplicit ? '$type(unkeyed)' : '$type($key)';
}

class _ConstructionTransaction {
  final List<void Function()> _rollbacks = [];
  bool _completed = false;

  void register(void Function() rollback) {
    if (_completed) return;
    _rollbacks.add(rollback);
  }

  void commit() {
    if (_completed) return;
    _completed = true;
    _rollbacks.clear();
  }

  void rollback() {
    if (_completed) return;
    _completed = true;
    for (final callback in _rollbacks.reversed) {
      try {
        callback();
      } catch (_) {
        // Preserve the original construction error. Individual lifecycle
        // cleanup already reports its own errors through ViewModelConfig.
      }
    }
    _rollbacks.clear();
  }
}

final List<_ConstructionIdentity> _activeConstructionLineage = [];
_ConstructionTransaction? _activeConstructionTransaction;

/// Registers cleanup owned by the currently building ViewModel object.
///
/// This is used by resource cleanup controllers and dependency scopes created
/// from constructors/onCreate. If the enclosing builder throws, their cleanup
/// callbacks, children and listeners are released before the error escapes.
void registerViewModelConstructionRollback(void Function() rollback) {
  _activeConstructionTransaction?.register(rollback);
}

/// Runs one cache-miss builder in a checked, failure-atomic synchronous
/// construction context.
R runInViewModelConstruction<R>({
  required Type type,
  required Object key,
  required bool isImplicit,
  required R Function() body,
}) {
  final cycle = _activeConstructionLineage.any((ancestor) {
    if (ancestor.type != type) return false;
    if (isImplicit) return true;
    return !ancestor.isImplicit && ancestor.key == key;
  });
  final current = _ConstructionIdentity(
    type: type,
    key: key,
    isImplicit: isImplicit,
  );
  if (cycle) {
    final path = <_ConstructionIdentity>[
      ..._activeConstructionLineage,
      current,
    ].map((item) => item.description).join(' -> ');
    throw ViewModelError(
      'Circular ViewModel construction detected: $path. '
      'Unkeyed ViewModels are compared by type within the current construction '
      'lineage; use explicit distinct keys only for intentional nesting.',
    );
  }

  final transaction = _ConstructionTransaction();
  final previousTransaction = _activeConstructionTransaction;
  _activeConstructionTransaction = transaction;
  _activeConstructionLineage.add(current);
  try {
    final result = body();
    transaction.commit();
    return result;
  } catch (_) {
    transaction.rollback();
    rethrow;
  } finally {
    _activeConstructionLineage.removeLast();
    _activeConstructionTransaction = previousTransaction;
  }
}
