/// Automatic disposal controller for ViewModel instances.
///
/// This file provides automatic lifecycle management for ViewModel instances,
/// ensuring proper cleanup when widgets are disposed. The controller tracks
/// instance usage and automatically removes watchers when no longer needed.
///
/// @author luwenjie on 2025/3/25 16:24:32
library;

import 'package:uuid/v4.dart';
import 'package:view_model/src/view_model/dependency_handler.dart';
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
  final Map<Object, bool> _notifierListeners = {};

  /// Human-readable name for this watcher, typically the widget class name.
  final String watcherName;

  final DependencyResolver dependencyResolver;

  /// Creates a new auto-dispose instance controller.
  ///
  /// Parameters:
  /// - [onRecreate]: Callback for handling instance recreation events
  /// - [watcherName]: Descriptive name for this watcher context
  AutoDisposeInstanceController({
    required this.onRecreate,
    required this.watcherName,
    required this.dependencyResolver,
  });

  /// Unique identifier for this controller instance.
  final _uuid = const UuidV4().generate();

  /// Gets the unique watcher ID combining the watcher name and UUID.
  ///
  /// This ID is used to identify this specific watcher in the ViewModel
  /// dependency tracking system.
  String get _watchId => "$watcherName:$_uuid";

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
  /// Throws [StateError] if [T] is dynamic.
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
      throw StateError("T must extends ViewModel");
    }
    factory = (factory ?? InstanceFactory<T>());
    factory = factory.copyWith(
      arg: factory.arg.copyWith(
        watchId: _watchId,
      ),
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
        e.recycle();
        return true;
      } else {
        return false;
      }
    });
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
  Future<void> dispose() async {
    for (final e in _instanceNotifiers) {
      if (e.instance is ViewModel) {
        (e.instance as ViewModel)
            .dependencyHandler
            .removeDependencyResolver(dependencyResolver);
      }
      e.removeWatcher(_watchId);
    }
    _instanceNotifiers.clear();
  }
}
