/// Automatic disposal controller for ViewModel instances.
///
/// This file provides automatic lifecycle management for ViewModel instances,
/// ensuring proper cleanup when widgets are disposed. The controller tracks
/// instance usage and automatically removes watchers when no longer needed.
///
/// @author luwenjie on 2025/3/25 16:24:32
library;

import 'package:flutter/foundation.dart';
import 'package:view_model/src/view_model/vef.dart';
import 'package:view_model/src/view_model/state_store.dart';
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
/// - Automatic watcher registration and cleanup
/// - Instance recreation handling
/// - Unique watcher identification
/// - Memory leak prevention
///
/// Example:
/// ```dart
/// final controller = AutoDisposeInstanceController(
///   onRecreate: () => setState(() {}),
///   watcherName: 'MyWidget',
/// );
///
/// // Get a ViewModel instance
/// final viewModel = controller.getInstance<MyViewModel>();
///
/// // Clean up when done
/// await controller.dispose();
/// ```
class AutoDisposeInstanceController {
  /// List of instance handles being tracked by this controller.
  final List<InstanceHandle> _instanceNotifiers = List.empty(growable: true);

  List<InstanceHandle> get instanceNotifiers => _instanceNotifiers;

  /// Callback function called when an instance needs to be recreated.
  ///
  /// This is typically used to trigger widget rebuilds when a ViewModel
  /// instance is recreated due to dependency changes.
  final Function() onRecreate;

  /// Map tracking which notifiers already have listeners attached.
  ///
  /// Prevents duplicate listener registration for the same instance handle.
  /// Map tracking which notifiers already have listeners attached.
  ///
  /// Prevents duplicate listener registration for the same instance handle.
  final Map<Object, VoidCallback> _notifierListeners = {};

  final Vef vef;

  /// Creates a new auto-dispose instance controller.
  ///
  /// Parameters:
  /// - [onRecreate]: Callback for handling instance recreation events
  /// - [binderName]: Descriptive name for this watcher context
  AutoDisposeInstanceController({
    required this.onRecreate,
    required this.vef,
  });

  /// Gets a ViewModel instance with automatic lifecycle management.
  ///
  /// This method retrieves or creates a ViewModel instance of type [T] and
  /// automatically registers this controller as a watcher. The instance will
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
  /// );
  /// ```
  T getInstance<T>({
    InstanceFactory<T>? factory,
  }) {
    if (T == dynamic) {
      throw ViewModelError("T must extends ViewModel");
    }
    factory = (factory ?? InstanceFactory<T>());
    factory = factory.copyWith(
      arg: factory.arg.copyWith(
        vefId: vef.id,
      ),
    );
    final InstanceHandle<T> notifier = instanceManager.getNotifier<T>(
      factory: factory,
    );
    if (!_notifierListeners.containsKey(notifier)) {
      _instanceNotifiers.add(notifier);
      final listener = () {
        switch (notifier.action) {
          case null:
            break;
          case InstanceAction.dispose:
            break;
          case InstanceAction.recreate:
            onRecreate.call();
            break;
        }
      };
      _notifierListeners[notifier] = listener;
      notifier.addListener(listener);
    }
    return notifier.instance;
  }

  List<T> getInstancesByTag<T>(Object tag, {bool listen = true}) {
    final notifiers = instanceManager.getNotifiersByTag<T>(tag);
    final List<T> result = [];
    for (final notifier in notifiers) {
      if (listen) {
        if (!_notifierListeners.containsKey(notifier)) {
          _instanceNotifiers.add(notifier);
          final listener = () {
            switch (notifier.action) {
              case null:
                break;
              case InstanceAction.dispose:
                break;
              case InstanceAction.recreate:
                onRecreate.call();
                break;
            }
          };
          _notifierListeners[notifier] = listener;
          notifier.addListener(listener);
        }
        // bind vef
        notifier.bindVef(vef.id);
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
      if (notifier.instance is ViewModel) {
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
      if (e.instance == instance) {
        e.unbindAll();
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
      if (e.instance == instance) {
        e.unbindVef(vef.id);
        break;
      }
    }
  }

  /// Disposes the controller and cleans up all tracked instances.
  ///
  /// This method removes this controller as a watcher from all tracked
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
    for (final e in _instanceNotifiers) {
      if (!e.isDisposed && e.instance is ViewModel) {
        (e.instance as ViewModel).refHandler.removeRef(vef);
      }
      e.unbindVef(vef.id);
      if (_notifierListeners.containsKey(e)) {
        e.removeListener(_notifierListeners[e]!);
      }
    }
    _notifierListeners.clear();
    _instanceNotifiers.clear();
  }
}
