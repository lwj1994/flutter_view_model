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

  /// Called when this controller starts tracking a handle.
  final void Function(InstanceHandle handle, ViewModel viewModel)?
      onInstanceAttached;

  /// Called before a tracked ViewModel is recycled or unbound.
  final void Function(InstanceHandle handle, ViewModel viewModel)?
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

  void _detachViewModelRef(InstanceHandle notifier) {
    final ViewModel? viewModel =
        !notifier.isDisposed && notifier.instance is ViewModel
            ? notifier.instance as ViewModel
            : null;
    if (viewModel == null) return;
    if (!viewModel.isDisposed) {
      viewModel.refHandler.removeRef(viewModelBinding);
    }
    onInstanceDetached?.call(notifier, viewModel);
  }

  /// Attaches a disposal listener to the notifier if not already attached.
  void _attachHandleListener(InstanceHandle notifier) {
    if (_disposed || _notifierListeners.containsKey(notifier)) return;
    ViewModel? trackedViewModel;
    if (!notifier.isDisposed && notifier.instance is ViewModel) {
      trackedViewModel = notifier.instance as ViewModel;
      try {
        onInstanceAttached?.call(notifier, trackedViewModel);
      } catch (_) {
        // `getNotifier` already added this controller's direct bind/ref. Roll
        // them back when dependency validation rejects the new edge.
        if (!trackedViewModel.isDisposed) {
          trackedViewModel.refHandler.removeRef(viewModelBinding);
        }
        if (!notifier.isDisposed) {
          notifier.unbind(viewModelBinding.id);
        }
        rethrow;
      }
    }
    if (!_instanceNotifiers.contains(notifier)) {
      _instanceNotifiers.add(notifier);
    }
    final listener = () {
      try {
        _detachViewModelRef(notifier);
        _detachNotifier(notifier);
        if (!instanceManager.isResetting) {
          onHandleDisposing.call();
        }
      } catch (e, stack) {
        reportViewModelError(e, stack, ErrorType.listener,
            'AutoDisposeInstanceController handle listener error');
      }
    };
    _notifierListeners[notifier] = listener;
    notifier.addListener(listener);
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
    if (_disposed) {
      throw ViewModelError(
          "AutoDisposeInstanceController.getInstance() called after dispose.");
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
    // getNotifier calls bind(bindingId) internally via the factory arg.
    // Order: bind (via getNotifier) → addRef → attachListener.
    final InstanceHandle<T> notifier = instanceManager.getNotifier<T>(
      factory: factory,
    );
    if (notifier.instance is ViewModel) {
      (notifier.instance as ViewModel).refHandler.addRef(viewModelBinding);
    }
    _attachHandleListener(notifier);
    return notifier.instance;
  }

  List<T> getInstancesByTag<T>(Object tag) {
    final notifiers = instanceManager.getNotifiersByTag<T>(tag);
    final List<T> result = [];
    for (final notifier in notifiers) {
      notifier.bind(viewModelBinding.id);
      if (notifier.instance is ViewModel) {
        (notifier.instance as ViewModel).refHandler.addRef(viewModelBinding);
      }
      _attachHandleListener(notifier);
      result.add(notifier.instance);
    }
    return result;
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
        _detachViewModelRef(notifier);
        _detachNotifier(notifier);
        notifier.unbind(viewModelBinding.id);
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
    for (final e in _instanceNotifiers) {
      try {
        if (!e.isDisposed && e.instance is ViewModel) {
          (e.instance as ViewModel).refHandler.removeRef(viewModelBinding);
        }
        // Remove listener before unbind, because unbind may trigger _recycle()
        // which disposes the ChangeNotifier, making removeListener fail.
        if (_notifierListeners.containsKey(e)) {
          e.removeListener(_notifierListeners[e]!);
        }
        e.unbind(viewModelBinding.id);
      } catch (e, stack) {
        reportViewModelError(e, stack, ErrorType.dispose,
            'AutoDisposeInstanceController dispose error');
      }
    }
    _notifierListeners.clear();
    _instanceNotifiers.clear();
  }
}
