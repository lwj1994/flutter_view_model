library;

import 'dart:collection';

class _ViewModelUpdateTransaction {
  final Set<Object> updatedBindings = HashSet.identity();
}

_ViewModelUpdateTransaction? _activeUpdateTransaction;

/// Runs [body] in one synchronous ViewModel propagation transaction.
///
/// Nested notifications reuse the current transaction so root bindings can
/// coalesce refresh requests from a diamond graph. Dependency bindings and
/// explicit business listeners continue to receive each notification.
R runInViewModelUpdateTransaction<R>(R Function() body) {
  if (_activeUpdateTransaction != null) {
    return body();
  }
  _activeUpdateTransaction = _ViewModelUpdateTransaction();
  try {
    return body();
  } finally {
    // The transaction is intentionally synchronous. Microtasks/Futures created
    // by listeners must start a fresh propagation transaction later.
    _activeUpdateTransaction = null;
  }
}

/// Returns whether [binding] has not updated in the current transaction yet.
bool markViewModelBindingUpdated(Object binding) {
  final transaction = _activeUpdateTransaction;
  return transaction == null || transaction.updatedBindings.add(binding);
}
