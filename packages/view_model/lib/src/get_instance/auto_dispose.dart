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
/// handles recreation events, and ensures proper cleanup when the controller
/// is disposed.
///
/// Key features:
/// - Automatic binding registration and cleanup
/// - Instance recreation handling
/// - Unique binding identification
/// - Memory leak prevention
///
/// Example:
/// ```dart
/// final controller = AutoDisposeInstanceController(
///   onRecreate: () => setState(() {}),
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

  /// Callback function called when an instance needs to be recreated.
  ///
  /// This is typically used to trigger widget rebuilds when a ViewModel
  /// instance is recreated due to dependency changes.
  final Function() onRecreate;

  /// Map tracking which notifiers already have listeners attached.
  ///
  /// Prevents duplicate listener registration for the same instance handle.
  final Map<Object, VoidCallback> _notifierListeners = {};

  final ViewModelBinding viewModelBinding;

  /// Creates a new auto-dispose instance controller.
  ///
  /// Parameters:
  /// - [onRecreate]: Callback for handling instance recreation events
  /// - [viewModelBinding]: The binding context for lifecycle management
  AutoDisposeInstanceController({
    required this.onRecreate,
    required this.viewModelBinding,
  });

  /// Attaches a recreate listener to the notifier if not already attached.
  void _attachRecreateListener(InstanceHandle notifier) {
    if (_disposed || _notifierListeners.containsKey(notifier)) return;
    if (!_instanceNotifiers.contains(notifier)) {
      _instanceNotifiers.add(notifier);
    }
    final listener = () {
      try {
        switch (notifier.action) {
          case null:
            break;
          case InstanceAction.dispose:
            break;
          case InstanceAction.recreate:
            if (!notifier.isDisposed && notifier.instance is ViewModel) {
              (notifier.instance as ViewModel).refHandler.addRef(
                    viewModelBinding,
                  );
            }
            onRecreate.call();
            break;
        }
      } catch (e, stack) {
        reportViewModelError(e, stack, ErrorType.listener,
            'AutoDisposeInstanceController recreate listener error');
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
    _attachRecreateListener(notifier);
    return notifier.instance;
  }

  List<T> getInstancesByTag<T>(Object tag, {bool listen = true}) {
    final notifiers = instanceManager.getNotifiersByTag<T>(tag);
    final List<T> result = [];
    for (final notifier in notifiers) {
      // Always bind + addRef to establish the binding relationship and keep
      // the instance alive. This matches read() semantics (bind without
      // listener).
      notifier.bind(viewModelBinding.id);
      if (notifier.instance is ViewModel) {
        (notifier.instance as ViewModel).refHandler.addRef(viewModelBinding);
      }
      if (listen) {
        // Register recreate listener for watch (listen: true) — rebuild on recreate.
        _attachRecreateListener(notifier);
      } else {
        // Track for cleanup (removeRef + unbind on dispose) without a recreate
        // listener. Without this, dispose() would skip these notifiers entirely.
        if (!_notifierListeners.containsKey(notifier) &&
            !_instanceNotifiers.contains(notifier)) {
          _instanceNotifiers.add(notifier);
        }
      }
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
        action(notifier.instance as ViewModel);
      }
    }
  }

  /// Forces disposal and recreation of a specific ViewModel instance.
  ///
  /// This method removes the specified instance from tracking and forces
  /// its disposal. The instance will be recreated on the next access.
  ///
  /// Parameters:
  /// - [instance]: The ViewModel instance to recycle
  ///
  /// Example:
  /// ```dart
  /// final viewModel = controller.getInstance<MyViewModel>();
  /// // Later, force recreation
  /// controller.recycle(viewModel);
  /// ```
  void recycle(Object instance) {
    _instanceNotifiers.removeWhere((e) {
      if (!e.isDisposed && e.instance == instance) {
        final listener = _notifierListeners.remove(e);
        if (listener != null) {
          e.removeListener(listener);
        }
        e.unbindAll(force: true);
        return true;
      } else {
        return false;
      }
    });
  }

  /// Unbinds this controller from a specific instance.
  ///
  /// The instance will drop this binder id from its handle. If no
  /// binders remain, the instance can be recycled automatically.
  void unbindInstance(Object instance) {
    for (final e in _instanceNotifiers) {
      if (!e.isDisposed && e.instance == instance) {
        e.unbind(viewModelBinding.id);
        break;
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
