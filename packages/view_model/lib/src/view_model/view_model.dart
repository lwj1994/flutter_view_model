// @author luwenjie on 2025/3/25 17:00:38

/// Core ViewModel implementation for Flutter applications.
///
/// This file contains the main ViewModel classes and interfaces that provide a
/// reactive state management solution for Flutter apps. It includes:
/// - [ViewModel]: Base mixin for stateless ViewModels
/// - [StateViewModel]: Abstract class for stateful ViewModels
/// - [ViewModelFactory]: Factory interface for creating ViewModels
/// - [ViewModelSpec]: Default implementation of ViewModelFactory
/// - [ViewModelLifecycle]: Interface for ViewModel lifecycle callbacks
///
/// The ViewModel system provides automatic lifecycle management,
/// dependency injection, and integration with Flutter's widget
/// system through mixins.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
// ignore: unnecessary_import
import 'package:meta/meta.dart' show internal;
import 'package:view_model/src/devtool/service.dart';
import 'package:view_model/src/devtool/tracker.dart';
import 'package:view_model/src/get_instance/manager.dart';
import 'package:view_model/src/get_instance/store.dart';
import 'package:view_model/src/log.dart';
import 'package:view_model/src/view_model/config.dart';
import 'package:view_model/src/view_model/view_model_binding.dart';

import 'package:view_model/src/view_model/binding_zone.dart';
import 'state_store.dart';

/// A ViewModel implementation that extends Flutter's [ChangeNotifier].
///
/// This class provides compatibility with existing Flutter code that uses
/// [ChangeNotifier] while adding ViewModel capabilities. The
/// [addListener] method
/// is overridden to use the ViewModel's [listen] method internally.
///
/// Example:
/// ```dart
/// class MyViewModel extends ChangeNotifierViewModel {
///   int _count = 0;
///   int get count => _count;
///
///   void increment() {
///     _count++;
///     notifyListeners();
///   }
/// }
/// ```
class ChangeNotifierViewModel extends ChangeNotifier with ViewModel {}

/// Base mixin class for all ViewModels in the application.
///
/// This mixin provides core functionality for ViewModels including:
/// - Lifecycle management through [InstanceLifeCycle]
/// - Listener management for reactive updates
/// - Static methods for reading existing ViewModels
/// - Integration with the ViewModel system
///
/// Implements [Listenable] for compatibility with Flutter's standard listener
/// patterns like [ListenableBuilder] and [AnimatedBuilder].
///
/// ViewModels using this mixin are automatically managed by the system and will
/// be disposed when no longer needed.
///
/// Example:
/// ```dart
/// class CounterViewModel with ViewModel {
///   int _count = 0;
///   int get count => _count;
///
///   void increment() {
///     _count++;
///     notifyListeners();
///   }
/// }
/// ```
mixin class ViewModel implements InstanceLifeCycle, Listenable {
  /// Returns the [ViewModelBinding] interface for accessing other ViewModels.
  ///
  /// This property allows you to use `viewModelBinding.watch` and `viewModelBinding.read` syntax,
  /// consistent with the "Universal Binding" pattern.
  @protected
  ViewModelBindingInterface get viewModelBinding => refHandler.binding;

  late InstanceArg _instanceArg;
  static final RouteObserver<PageRoute> routeObserver =
      RouteObserver<PageRoute>();

  /// Gets the tag associated with this ViewModel instance.
  ///
  /// The tag is set by the [ViewModelFactory.tag] method and can be used to
  /// identify or categorize ViewModel instances.
  Object? get tag => _instanceArg.tag;

  static bool _initialized = false;
  static bool _initializedDevtool = false;

  static final List<ViewModelLifecycle> _viewModelLifecycles =
      List.empty(growable: true);

  /// Attempts to read a ViewModel instance by [key] or [tag].
  ///
  /// Returns `null` if no matching ViewModel is found, unlike [readCached]
  /// which throws an exception.
  ///
  /// This method is useful for safely accessing a cached ViewModel without
  /// causing
  /// an error if it doesn't exist.
  ///
  /// Parameters:
  /// - [key]: The unique key to search for.
  /// - [tag]: The tag to search for.
  ///
  /// Returns the ViewModel instance if found, otherwise `null`.
  ///
  /// Example:
  /// ```dart
  /// final vm = ViewModel.maybeReadCached<MyViewModel>(key: 'my-key');
  /// if (vm != null) {
  ///   // Use the ViewModel
  /// }
  /// ```
  static T? maybeReadCached<T extends ViewModel>({Object? key, Object? tag}) {
    try {
      return readCached<T>(key: key, tag: tag);
    } catch (e) {
      return null;
    }
  }

  /// Executes the given [block] and automatically calls [notifyListeners] when
  /// it completes.
  ///
  /// This is a convenience wrapper to ensure that any asynchronous or
  /// synchronous
  /// update logic always triggers a UI refresh, preventing missed
  /// notifications.
  ///
  /// Example:
  /// ```dart
  /// await update(() async {
  ///   await repository.save(data);
  ///   _counter++;
  /// });
  /// ```
  Future<void> update(FutureOr<dynamic> Function() block) async {
    await block.call();
    notifyListeners();
  }

  /// Reads a ViewModel instance by [key] or [tag].
  ///
  /// This method searches for an existing ViewModel instance
  /// using the following priority:
  /// 1. If [key] is provided, it searches by the unique key.
  /// 2. If [tag] is provided, it searches by the tag.
  /// 3. If neither is provided, it finds the most recently
  /// created instance of type [T].
  ///
  /// This method is for accessing already-created and cached ViewModels.
  /// It does
  /// not create new instances.
  ///
  /// Parameters:
  /// - [key]: The unique key from [ViewModelFactoryBase.key].
  /// - [tag]: The tag from [ViewModelFactoryBase.tag].
  ///
  /// Returns the matching ViewModel instance.
  ///
  /// Throws a [ViewModelError] if:
  /// - No matching ViewModel is found.
  /// - The found ViewModel has been disposed.
  ///
  /// Example:
  /// ```dart
  /// final vm = ViewModel.readCached<MyViewModel>(key: 'global-counter');
  /// vm.increment();
  /// ```
  static T readCached<T extends ViewModel>({Object? key, Object? tag}) {
    T? vm;

    /// find key firstly
    if (key != null) {
      try {
        vm = instanceManager.get<T>(
          factory: InstanceFactory<T>(
              arg: InstanceArg(
            key: key,
          )),
        );
      } catch (e) {
        // rethrow if tag is null
        if (tag == null) {
          rethrow;
        }
      }
    }

    // find newly cache
    vm ??= instanceManager.get<T>(
      factory: InstanceFactory<T>(
          arg: InstanceArg(
        tag: tag,
      )),
    );

    if (vm.isDisposed) {
      throw ViewModelError("$T is disposed");
    }
    return vm;
  }

  /// Adds a global lifecycle observer to all ViewModels.
  ///
  /// The [lifecycle] will receive callbacks for all ViewModel lifecycle events
  /// including creation, watcher addition/removal, and disposal.
  ///
  /// Returns a function that can be called to remove the lifecycle observer.
  ///
  /// Example:
  /// ```dart
  /// final removeLifecycle = ViewModel.addLifecycle(MyLifecycleObserver());
  /// // Later, remove the observer
  /// removeLifecycle();
  /// ```
  static Function() addLifecycle(ViewModelLifecycle lifecycle) {
    _viewModelLifecycles.add(lifecycle);
    return () {
      _viewModelLifecycles.remove(lifecycle);
    };
  }

  /// Removes a global lifecycle observer.
  ///
  /// Parameters:
  /// - [value]: The lifecycle observer to remove
  static void removeLifecycle(ViewModelLifecycle value) {
    _viewModelLifecycles.remove(value);
  }

  final List<VoidCallback> _listeners = [];
  static ViewModelConfig _config = ViewModelConfig();

  /// Gets the current ViewModel configuration.
  ///
  /// The configuration controls global ViewModel behavior and can be set during
  /// initialization via [initialize].
  static ViewModelConfig get config => _config;

  final _autoDisposeController = AutoDisposeController();
  bool _isDisposed = false;

  /// Returns `true` if this ViewModel has been disposed.
  ///
  /// Once disposed, the ViewModel should not be used and will throw errors if
  /// methods are called on it.
  bool get isDisposed => _isDisposed;

  /// Returns `true` if this ViewModel has any active listeners.
  ///
  /// This can be useful for determining if the ViewModel is being observed
  /// by any
  /// widgets or other components.
  bool get hasListeners => _listeners.isNotEmpty;

  /// Handler for managing ViewModel dependencies.
  /// This encapsulates all dependency-related logic and
  /// provides a clean separation of concerns.
  @internal
  final ViewModelBindingHandler refHandler = ViewModelBindingHandler();

  /// Called when a dependency ViewModel notifies changes.
  ///
  /// This method is called when a dependency ViewModel that this ViewModel is
  /// listening to notifies changes. By default, it simply notifies listeners of
  /// this ViewModel.
  ///
  /// Parameters:
  /// - [vm]: The dependency ViewModel that notified changes
  @mustCallSuper
  @protected
  void onDependencyNotify(ViewModel vm) {}

  /// Adds a listener to this ViewModel.
  ///
  /// This method is part of the [Listenable] interface, allowing ViewModel
  /// to work with Flutter's standard listener patterns like
  /// [ListenableBuilder].
  ///
  /// Parameters:
  /// - [listener]: The listener function to add
  @override
  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  /// Removes a listener from this ViewModel.
  ///
  /// This method is part of the [Listenable] interface.
  ///
  /// Parameters:
  /// - [listener]: The listener function to remove
  @override
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  /// Adds a dispose callback that will be executed when this ViewModel is
  /// disposed.
  ///
  /// This is useful for cleaning up resources like streams, timers, or other
  /// subscriptions that need to be disposed when the ViewModel is no
  /// longer needed.
  ///
  /// Parameters:
  /// - [block]: The cleanup function to execute on disposal
  ///
  /// Example:
  /// ```dart
  /// class MyViewModel with ViewModel {
  ///   late StreamSubscription _subscription;
  ///
  ///   MyViewModel() {
  ///     _subscription = someStream.listen(...);
  ///     addDispose(() => _subscription.cancel());
  ///   }
  /// }
  /// ```
  @protected
  void addDispose(Function() block) {
    _autoDisposeController.addDispose(block);
  }

  /// Adds a listener to this ViewModel that will be called when
  /// [notifyListeners] is invoked.
  ///
  /// Returns a function that can be called to remove the listener.
  ///
  /// Parameters:
  /// - [onChanged]: The callback function to invoke when the ViewModel changes
  ///
  /// Example:
  /// ```dart
  /// final removeListener = viewModel.listen(onChanged: () {
  ///   print('ViewModel changed!');
  /// });
  /// // Later, remove the listener
  /// removeListener();
  /// ```
  Function() listen({required VoidCallback onChanged}) {
    _listeners.add(onChanged);
    return () {
      _listeners.remove(onChanged);
    };
  }

  /// Notifies all registered listeners that this ViewModel has changed.
  ///
  /// This method should be called whenever the ViewModel's state changes
  /// and listeners need to be updated (e.g., to rebuild widgets).
  ///
  /// Any exceptions thrown by listeners are caught and handled via the
  /// global [ViewModelConfig.onListenerError] callback. If no custom handler
  /// is provided, errors are logged. This prevents one listener from
  /// affecting others.
  void notifyListeners() {
    for (final element in _listeners) {
      try {
        element.call();
      } catch (e, stack) {
        final handler = config.onListenerError;
        if (handler != null) {
          handler(e, stack, 'notifyListeners');
        } else {
          viewModelLog("error on notifyListeners: $e\n$stack");
        }
      }
    }
  }

  /// Initializes the ViewModel system.
  ///
  /// This method must be called before using any ViewModels in your
  /// application.
  /// It sets up the global configuration and lifecycle observers.
  ///
  /// Parameters:
  /// - [config]: Optional configuration to customize ViewModel behavior
  /// - [lifecycles]: Global lifecycle observers to add to all ViewModels
  ///
  /// Example:
  /// ```dart
  /// void main() {
  ///   ViewModel.initialize(
  ///     config: ViewModelConfig(enableLogging: true),
  ///     lifecycles: [MyGlobalLifecycleObserver()],
  ///   );
  ///   runApp(MyApp());
  /// }
  /// ```
  ///
  /// Note: This method can only be called once. Subsequent calls are ignored.
  static void initialize(
      {ViewModelConfig? config,
      Iterable<ViewModelLifecycle> lifecycles = const []}) {
    if (_initialized) return;
    _initialized = true;
    if (config != null) {
      _config = config;
    }
    _viewModelLifecycles.addAll(lifecycles);
    _initDevtool();
  }

  @visibleForTesting
  static void reset() {
    _initialized = false;
    _config = ViewModelConfig();
    _viewModelLifecycles.clear();
  }

  /// Initializes DevTools integration if in debug mode.
  ///
  /// This method is called automatically by [initialize] and sets up:
  /// - Dependency tracking for DevTools visualization
  /// - DevTools service for runtime inspection
  ///
  /// Only runs in debug mode and can only be called once.
  static void _initDevtool() {
    if (_initializedDevtool) return;
    _initializedDevtool = true;
    if (kDebugMode) {
      _viewModelLifecycles.add(DevToolTracker.instance);
      DevToolsService.instance.initialize();
    }
  }

  @override
  @protected
  @mustCallSuper
  void onCreate(InstanceArg arg) {
    _initDevtool();
    _instanceArg = arg;
    for (final element in _viewModelLifecycles) {
      element.onCreate(this, arg);
    }
  }

  @protected
  @mustCallSuper
  @override
  void onBind(InstanceArg arg, String bindingId) {
    for (final element in _viewModelLifecycles) {
      element.onBind(this, arg, bindingId);
    }
  }

  @protected
  @mustCallSuper
  @override
  void onUnbind(InstanceArg arg, String bindingId) {
    for (final element in _viewModelLifecycles) {
      element.onUnbind(this, arg, bindingId);
    }
  }

  @override
  @mustCallSuper
  @protected
  void onDispose(InstanceArg arg) {
    _isDisposed = true;
    _autoDisposeController.dispose();
    refHandler.dispose();
    dispose();
    for (final element in _viewModelLifecycles) {
      element.onDispose(this, arg);
    }
  }

  @protected
  @mustCallSuper
  void dispose() {}
}

/// Abstract base class for ViewModels that manage state of type [T].
///
/// This class extends the basic [ViewModel] functionality with state management
/// capabilities. It automatically handles state changes, notifications, and
/// provides both general listeners and state-specific listeners.
///
/// The state is immutable - each change creates a new state
/// instance via [setState].
///
/// Example:
/// ```dart
/// class CounterState {
///   final int count;
///   const CounterState(this.count);
/// }
///
/// class CounterViewModel extends StateViewModel<CounterState> {
///   CounterViewModel() : super(state: CounterState(0));
///
///   void increment() {
///     setState(CounterState(state.count + 1));
///   }
/// }
/// ```
abstract class StateViewModel<T> with ViewModel {
  late final ViewModelStateStore<T> _store;
  final List<Function(T? previous, T state)> _stateListeners = [];

  /// Adds a state-specific listener that receives both previous and
  /// current state.
  ///
  /// Unlike the general [listen] method, this provides access to both the
  /// previous state and the new state, allowing for more granular
  /// change detection.
  ///
  /// Parameters:
  /// - [onChanged]: Callback that receives (previousState, currentState)
  ///
  /// Returns a function to remove the listener.
  ///
  /// Example:
  /// ```dart
  /// final removeListener = viewModel.listenState(
  ///   onChanged: (previous, current) {
  ///     if (previous?.count != current.count) {
  ///       print('Count changed from ${previous?.count} to ${current.count}');
  ///     }
  ///   },
  /// );
  /// ```
  Function() listenState({required Function(T? previous, T state) onChanged}) {
    _stateListeners.add(onChanged);
    return () {
      _stateListeners.remove(onChanged);
    };
  }

  /// Adds a listener for a selected property derived from the state.
  ///
  /// This method observes changes to a specific field or computed value of
  /// the state, rather than the entire state object. It invokes [onChanged]
  /// only when the selected property's value changes according to [equals].
  ///
  /// Parameters:
  /// - [selector]: Selector function that maps the full state `T` to
  /// the watched
  ///   property `S` (e.g., `(s) => s.count`).
  /// - [onChanged]: Callback receiving `(previousSelected, currentSelected)`.
  ///
  /// Returns a function to remove this listener.
  ///
  /// Example:
  /// ```dart
  /// // Function-level comment: Listen to only the `count` field changes.
  /// final remove = vm.listenStateSelect<int>(
  ///   selector: (s) => s.count,
  ///   onChanged: (prev, curr) {
  ///     // React only when `count` changes
  ///   },
  /// );
  /// ```
  Function() listenStateSelect<S>({
    required S Function(T state) selector,
    required void Function(S? previous, S current) onChanged,
  }) {
    final equals = ViewModel.config.equals ?? ((a, b) => a == b);
    // Wrap into a full-state listener to reuse the existing dispatch path.
    // ignore: prefer_final_locals
    Function(T? previous, T state) wrapper = (prevState, currState) {
      final S? prevSel = prevState == null ? null : selector(prevState);
      final S currSel = selector(currState);
      if (!equals(prevSel, currSel)) {
        onChanged(prevSel, currSel);
      }
    };
    _stateListeners.add(wrapper);
    return () {
      _stateListeners.remove(wrapper);
    };
  }

  late final T initState;

  /// Creates a new StateViewModel with the given initial state.
  ///
  /// Parameters:
  /// - [state]: The initial state value
  /// - [equals]: Optional per-instance equality function to determine if
  ///   states are equal. If not provided, falls back to global config or
  ///   identity comparison.
  ///
  /// Example with custom equality:
  /// ```dart
  /// class UserViewModel extends StateViewModel<User> {
  ///   UserViewModel() : super(
  ///     state: User(id: 1),
  ///     equals: (prev, curr) => prev.id == curr.id, // Compare by ID only
  ///   );
  /// }
  /// ```
  StateViewModel({
    required T state,
    bool Function(T previous, T current)? equals,
  }) {
    initState = state;
    _store = ViewModelStateStore(
      initialState: state,
      equals: equals,
      onStateChanged: _handleStateChanged,
    );
  }

  /// Handles state changes synchronously.
  ///
  /// This method is called immediately when state changes, ensuring
  /// synchronous notification consistent with ViewModel behavior.
  void _handleStateChanged(DiffState<T> event) {
    if (_isDisposed) return;

    // Phase 1: Notify state listeners with previous and current state
    for (final element in _stateListeners) {
      try {
        element.call(event.previousState, event.currentState);
      } catch (e, stack) {
        final handler = ViewModel.config.onListenerError;
        if (handler != null) {
          handler(e, stack, 'stateListener');
        } else {
          viewModelLog("error on stateListener: $e\n$stack");
        }
      }
    }

    // Phase 2: Notify general listeners
    for (final element in _listeners) {
      try {
        element.call();
      } catch (e, stack) {
        final handler = ViewModel.config.onListenerError;
        if (handler != null) {
          handler(e, stack, 'notifyListeners');
        } else {
          viewModelLog("error on notifyListeners: $e\n$stack");
        }
      }
    }
  }

  /// Removes a state-specific listener.
  ///
  /// Parameters:
  /// - [listener]: The listener function to remove
  void removeStateListener(Function(T? previous, T state) listener) {
    _stateListeners.remove(listener);
  }

  @override
  void notifyListeners() {
    if (_isDisposed) {
      viewModelLog("notifyListeners after Disposed");
      return;
    }
    _store.notifyListeners();
  }

  /// Updates the state and notifies all listeners.
  ///
  /// This method replaces the current state with [state] and automatically
  /// triggers notifications to both general listeners and state listeners.
  ///
  /// Parameters:
  /// - [state]: The new state to set
  ///
  /// Note: This method is protected and should only be called from within
  /// the ViewModel implementation.
  ///
  /// This method uses an equality function to determine if the new state is
  /// the same as the current state. If they are considered the same, no update
  /// will be triggered. The equality check follows this priority:
  /// 1. Instance-level `equals` (if provided in constructor)
  /// 2. Global `ViewModelConfig.equals` (if configured)
  /// 3. Identity comparison using `identical()`
  ///
  /// Example:
  /// ```dart
  /// void increment() {
  ///   setState(CounterState(state.count + 1));
  /// }
  /// ```
  @protected
  void setState(T state) {
    if (_isDisposed) {
      viewModelLog("setState after Disposed");
      return;
    }
    try {
      _store.setState(state);
    } catch (e) {
      onError(e);
    }
  }

  /// Called when an error occurs during state operations.
  ///
  /// Override this method to provide custom error handling.
  /// By default, errors are logged using [viewModelLog].
  ///
  /// Parameters:
  /// - [e]: The error that occurred
  @protected
  void onError(dynamic e) {
    viewModelLog("error :$e");
  }

  /// Gets the previous state before the last [setState] call.
  ///
  /// Returns `null` if no previous state exists (i.e., this is the
  /// initial state).
  T? get previousState {
    return _store.previousState;
  }

  /// Gets the current state.
  ///
  /// This is the main way to access the current state from outside the
  /// ViewModel.
  T get state {
    return _store.state;
  }

  @mustCallSuper
  @override
  void dispose() {
    _store.dispose();
    _listeners.clear();
    _stateListeners.clear();
    super.dispose();
  }

  @override
  void onCreate(InstanceArg arg) {
    super.onCreate(arg);
  }
}

/// Controller for managing automatic disposal of resources.
///
/// This class collects disposal callbacks and executes them all when
/// [dispose] is called. It's used internally by ViewModels to ensure
/// proper cleanup of resources.
class AutoDisposeController {
  final _disposeSet = <Function()?>[];

  /// Adds a disposal callback to be executed when [dispose] is called.
  ///
  /// Parameters:
  /// - [block]: The cleanup function to execute
  Future<void> addDispose(Function() block) async {
    _disposeSet.add(block);
  }

  /// Executes all registered disposal callbacks.
  ///
  /// Any exceptions thrown by disposal callbacks are caught and handled via
  /// the global [ViewModelConfig.onDisposeError] callback. If no custom
  /// handler is provided, errors are logged. This prevents one callback from
  /// affecting others.
  void dispose() {
    for (final element in _disposeSet) {
      try {
        element?.call();
      } catch (e, stack) {
        final handler = ViewModel.config.onDisposeError;
        if (handler != null) {
          handler(e, stack);
        } else {
          viewModelLog("AutoDisposeMixin error: $e\n$stack");
        }
      }
    }
  }
}

/// Abstract factory interface for creating ViewModel instances.
///
/// This mixin defines the contract for creating and configuring ViewModels.
/// Implementations should provide the logic for building ViewModels and
/// optionally specify sharing behavior through keys and tags.
///
/// Example:
/// ```dart
/// class MyViewModelFactory with ViewModelFactoryBase<MyViewModel> {
///   @override
///   MyViewModel build() => MyViewModel();
///
///   @override
///   Object? key() => 'shared-instance'; // Optional: for sharing
///
///   @override
///   Object? tag() => 'my-tag'; // Optional: for identification
/// }
/// ```
abstract mixin class ViewModelFactory<T> {
  static const _defaultShareId = Object();

  /// Returns a unique key for sharing ViewModel instances.
  ///
  /// ViewModels with the same key will be shared across different widgets.
  /// If this returns `null`, a new instance will be created each time.
  ///
  /// By default, this returns a shared key when deprecated singleton switches
  /// are enabled, otherwise `null`.
  ///
  /// Example:
  /// ```dart
  /// @override
  /// Object? key() => 'global-counter'; // Share across app
  /// ```
  // ignore: deprecated_member_use_from_same_package
  Object? key() => singleton() ? _defaultShareId : null;

  /// Returns a tag to identify or categorize this ViewModel.
  ///
  /// Tags can be used to find ViewModels by category rather than type.
  /// The tag is accessible via [ViewModel.tag] and can be used with
  /// [ViewModel.readCached] to find ViewModels by tag.
  ///
  /// Example:
  /// ```dart
  /// @override
  /// Object? tag() => 'user-data';
  /// ```
  Object? tag() => null;

  /// Creates and returns a new instance of the ViewModel.
  ///
  /// This method is called when a new ViewModel instance is needed.
  /// It should contain the logic for constructing the ViewModel with
  /// any required dependencies or initial state.
  ///
  /// Example:
  /// ```dart
  /// @override
  /// MyViewModel build() {
  ///   return MyViewModel(initialData: fetchInitialData());
  /// }
  /// ```
  T build();

  /// (Deprecated) Returns `true` if this factory should create singleton
  /// instances. Use [key] instead.
  ///
  /// Kept for migration safety: removing this API can cause a silent behavior
  /// change in older factories that forgot `@override`.
  @Deprecated('Use key() instead. '
      'singleton() will be removed in a future major release.')
  bool singleton() => false;

  /// Returns `true` if the instance should live forever (never be disposed).
  bool aliveForever() => false;
}

/// Abstract interface for observing ViewModel lifecycle events.
///
/// Implement this interface to receive callbacks when ViewModels are created,
/// watched, unwatched, or disposed. This is useful for logging, analytics,
/// debugging, or other cross-cutting concerns.
///
/// Example:
/// ```dart
/// class LoggingLifecycle extends ViewModelLifecycle {
///   @override
///   void onCreate(ViewModel viewModel, InstanceArg arg) {
///     print('ViewModel created: ${viewModel.runtimeType}');
///   }
///
///   @override
///   void onDispose(ViewModel viewModel, InstanceArg arg) {
///     print('ViewModel disposed: ${viewModel.runtimeType}');
///   }
/// }
/// ```
abstract class ViewModelLifecycle {
  /// Called when a ViewModel instance is created.
  ///
  /// Parameters:
  /// - [viewModel]: The newly created ViewModel
  /// - [arg]: Creation arguments including key, tag, and other metadata
  void onCreate(ViewModel viewModel, InstanceArg arg) {}

  /// Called when a new watcher is added to a ViewModel.
  ///
  /// Parameters:
  /// - [viewModel]: The ViewModel being watched
  /// - [arg]: Instance arguments
  /// - [bindingId]: Unique identifier for the new watcher
  void onBind(ViewModel viewModel, InstanceArg arg, String bindingId) {}

  /// Called when a watcher is removed from a ViewModel.
  ///
  /// Parameters:
  /// - [viewModel]: The ViewModel being unwatched
  /// - [arg]: Instance arguments
  /// - [bindingId]: Unique identifier for the removed watcher
  void onUnbind(ViewModel viewModel, InstanceArg arg, String bindingId) {}

  /// Called when a ViewModel is disposed.
  ///
  /// Parameters:
  /// - [viewModel]: The ViewModel being disposed
  /// - [arg]: Instance arguments
  void onDispose(ViewModel viewModel, InstanceArg arg) {}
}
