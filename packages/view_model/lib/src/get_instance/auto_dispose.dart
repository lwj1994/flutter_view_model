library;

import 'package:flutter/foundation.dart';
import 'package:view_model/src/log.dart';
import 'package:view_model/src/view_model/state_store.dart';
import 'package:view_model/src/view_model/view_model_binding.dart';
import 'package:view_model/src/view_model/config.dart';
import 'package:view_model/src/view_model/view_model.dart';

import 'manager.dart';
import 'store.dart';

/// Controller for automatic disposal of ViewModel instances.
///
/// This class manages the lifecycle of ViewModel instances within a specific
/// context (typically a widget). It automatically tracks instance usage,
/// observes handle disposal, and ensures proper cleanup when the controller
/// is disposed.
///
/// Key features:
/// - Automatic binding registration and cleanup
/// - Handle disposal notifications
/// - Unique binding identification
/// - Memory leak prevention
///
/// Example:
/// ```dart
/// final controller = AutoDisposeInstanceController(
///   onHandleDisposing: () => setState(() {}),
///   viewModelBinding: viewModelBinding,
/// );
///
/// // Get a ViewModel instance
/// final viewModel = controller.getInstance<MyViewModel>();
///
/// // Clean up when done
/// controller.dispose();
/// ```
class AutoDisposeInstanceController {
  bool _disposed = false;

  /// List of instance handles being tracked by this controller.
  final List<InstanceHandle> _instanceNotifiers = List.empty(growable: true);

  List<InstanceHandle> get instanceNotifiers =>
      List.unmodifiable(_instanceNotifiers);

  /// Callback invoked while a tracked instance handle is being disposed.
  ///
  /// The handle has already been removed from this controller and the Store,
  /// but its ViewModel has not run `onDispose` yet. This is typically used to
  /// trigger owner updates so getter-based resolution can follow the normal
  /// cache-miss path on the next access.
  final VoidCallback onHandleDisposing;

  /// Validates an edge without mutating ownership or invoking lifecycle code.
  final void Function(InstanceHandle handle, ViewModel viewModel)?
      onInstanceAttaching;

  /// Commits local tracking and returns optional work to publish after binding.
  final VoidCallback? Function(InstanceHandle handle, ViewModel viewModel)?
      onInstanceAttached;

  /// Called before a tracked ViewModel is recycled or unbound.
  final VoidCallback? Function(InstanceHandle handle, ViewModel viewModel)?
      onInstanceDetached;

  /// Map tracking which notifiers already have listeners attached.
  ///
  /// Prevents duplicate listener registration for the same instance handle.
  final Map<Object, VoidCallback> _notifierListeners = {};

  final ViewModelBinding viewModelBinding;

  /// Creates a new auto-dispose instance controller.
  ///
  /// Parameters:
  /// - [onHandleDisposing]: Callback for tracked handle disposal notification
  /// - [viewModelBinding]: The binding context for lifecycle management
  AutoDisposeInstanceController({
    required this.onHandleDisposing,
    required this.viewModelBinding,
    this.onInstanceAttaching,
    this.onInstanceAttached,
    this.onInstanceDetached,
  });

  void _detachNotifier(InstanceHandle notifier) {
    _instanceNotifiers.remove(notifier);
    final listener = _notifierListeners.remove(notifier);
    if (listener != null) {
      notifier.removeListener(listener);
    }
  }

  void _requireLive(InstanceHandle notifier) {
    if (_disposed ||
        viewModelBinding.isDisposed ||
        notifier.isDisposed ||
        notifier.isRecycling) {
      throw ViewModelError('Cannot resolve an instance for a disposed binding '
          'or while the instance is being recycled.');
    }
  }

  void _validateAttachment(InstanceHandle notifier) {
    _requireLive(notifier);
    if (!_notifierListeners.containsKey(notifier) &&
        notifier.instance is ViewModel) {
      onInstanceAttaching?.call(notifier, notifier.instance as ViewModel);
    }
  }

  void _detachHandle(InstanceHandle notifier) {
    if (!_notifierListeners.containsKey(notifier)) return;
    // Stop tracking before callbacks: a callback can resolve the same cached
    // generation again, installing a new independently owned registration.
    _detachNotifier(notifier);
    final target = !notifier.isDisposed ? notifier.instance : null;
    final publish =
        target is ViewModel ? onInstanceDetached?.call(notifier, target) : null;
    notifier.unbindOwner(viewModelBinding);
    publish?.call();
  }

  VoidCallback? _attachHandle(InstanceHandle notifier) {
    _validateAttachment(notifier);
    if (_notifierListeners.containsKey(notifier)) return null;
    final target = notifier.instance;
    final publish =
        target is ViewModel ? onInstanceAttached?.call(notifier, target) : null;
    final listener = () {
      try {
        _detachHandle(notifier);
        if (!instanceManager.isResetting && !_disposed) {
          onHandleDisposing.call();
        }
      } catch (e, stack) {
        reportViewModelError(e, stack, ErrorType.listener,
            'AutoDisposeInstanceController handle listener error');
      }
    };
    _instanceNotifiers.add(notifier);
    _notifierListeners[notifier] = listener;
    notifier.addListener(listener);
    try {
      // Validation, adjacency and disposal tracking precede the first onBind.
      // bindOwner commits both ownership views before publishing callbacks.
      notifier.bindOwner(viewModelBinding);
      if (identical(_notifierListeners[notifier], listener)) publish?.call();
      _requireLive(notifier);
      if (!notifier.containsDirectBinding(viewModelBinding.id)) {
        throw ViewModelError(
            'Ownership was released while binding an instance.');
      }
      // Return this attempt's token even if onBind installed a replacement.
      // Batch rollback compares identities before releasing ownership.
      return listener;
    } catch (_) {
      // Do not tear down a replacement registration created by a reentrant
      // unbind/read. Only roll back the registration made by this attempt.
      if (identical(_notifierListeners[notifier], listener)) {
        _detachHandle(notifier);
      }
      rethrow;
    }
  }

  /// Gets a ViewModel instance with automatic lifecycle management.
  ///
  /// This method retrieves or creates a ViewModel instance of type [T] and
  /// automatically registers this controller as a binding. The instance will
  /// be tracked for automatic cleanup when the controller is disposed.
  ///
  /// Type parameter [T] must be a ViewModel type, not dynamic.
  ///
  /// Parameters:
  /// - [factory]: Optional factory for creating the instance. If not provided,
  ///   a default factory will be created.
  ///
  /// Returns the ViewModel instance of type [T].
  ///
  /// Throws [ViewModelError] if [T] is dynamic.
  ///
  /// Example:
  /// ```dart
  /// final viewModel = controller.getInstance<MyViewModel>();
  /// final customViewModel = controller.getInstance<MyViewModel>(
  ///   factory: InstanceFactory<MyViewModel>(
  ///     arg: InstanceArg(key: 'custom'),
  ///   ),
  ///   viewModelBinding: viewModelBinding,
  /// );
  /// ```
  T getInstance<T>({
    InstanceFactory<T>? factory,
  }) {
    return getHandle<T>(factory: factory).instance;
  }

  /// Same as [getInstance], but returns the tracked [InstanceHandle].
  ///
  /// The binding uses the handle to recognize later cache hits without
  /// re-entering the Store.
  InstanceHandle<T> getHandle<T>({
    InstanceFactory<T>? factory,
  }) {
    if (_disposed) {
      throw ViewModelError(
          "AutoDisposeInstanceController.getHandle() called after dispose.");
    }
    if (T == dynamic) {
      throw ViewModelError("T must extends ViewModel");
    }
    factory = (factory ?? InstanceFactory<T>());
    factory = factory.copyWith(
      arg: factory.arg.copyWith(
        bindingId: viewModelBinding.id,
      ),
    );
    return instanceManager.getNotifier<T>(
      factory: factory,
      onResolve: _attachHandle,
    );
  }

  List<T> getInstancesByTag<T>(Object tag) {
    if (_disposed || viewModelBinding.isDisposed) {
      throw ViewModelError(
        'AutoDisposeInstanceController.getInstancesByTag() called after '
        'dispose.',
      );
    }
    final notifiers = instanceManager.getNotifiersByTag<T>(tag);
    // A rejected member must not partially bind the rest of a tag batch.
    for (final notifier in notifiers) {
      _validateAttachment(notifier);
    }
    final added = <InstanceHandle, VoidCallback>{};
    try {
      final result = <T>[];
      for (final notifier in notifiers) {
        final registration = _attachHandle(notifier);
        if (registration != null) added[notifier] = registration;
        result.add(notifier.instance);
      }
      return result;
    } catch (_) {
      for (final entry in added.entries.toList(growable: false).reversed) {
        if (identical(_notifierListeners[entry.key], entry.value)) {
          _detachHandle(entry.key);
        }
      }
      rethrow;
    }
  }

  /// Executes an action for all tracked ViewModel instances.
  ///
  /// This method iterates through all tracked instance notifiers and applies
  /// the given action to each ViewModel instance.
  void performForAllInstances(void Function(ViewModel viewModel) action) {
    for (final notifier in _instanceNotifiers) {
      if (!notifier.isDisposed && notifier.instance is ViewModel) {
        try {
          action(notifier.instance as ViewModel);
        } catch (e, stack) {
          reportViewModelError(
              e, stack, ErrorType.lifecycle, 'performForAllInstances error');
        }
      }
    }
  }

  /// Unbinds this controller from a specific instance.
  ///
  /// The instance will drop this binder id from its handle. If no
  /// binders remain, the instance can be recycled automatically.
  void unbindInstance(Object instance) {
    final notifiers = List<InstanceHandle>.of(_instanceNotifiers);
    for (final notifier in notifiers) {
      if (!notifier.isDisposed && identical(notifier.instance, instance)) {
        _detachHandle(notifier);
        return;
      }
    }
  }

  /// Disposes the controller and cleans up all tracked instances.
  ///
  /// This method removes this controller as a binding from all tracked
  /// ViewModel instances and clears the internal tracking lists. This
  /// prevents memory leaks and ensures proper cleanup.
  ///
  /// Should be called when the associated widget or context is disposed.
  ///
  /// Example:
  /// ```dart
  /// @override
  /// void dispose() {
  ///   controller.dispose();
  ///   super.dispose();
  /// }
  /// ```
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final notifier in _instanceNotifiers.toList(growable: false)) {
      try {
        _detachHandle(notifier);
      } catch (e, stack) {
        reportViewModelError(e, stack, ErrorType.dispose,
            'AutoDisposeInstanceController dispose error');
      }
    }
    _notifierListeners.clear();
    _instanceNotifiers.clear();
  }
}
