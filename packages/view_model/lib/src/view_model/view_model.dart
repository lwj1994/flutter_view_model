// @author luwenjie on 2025/3/25 17:00:38

/// Core ViewModel implementation for Flutter applications.
///
/// This file contains the main ViewModel classes and interfaces that provide
/// a reactive state management solution for Flutter apps. It includes:
/// - [ViewModel]: Base mixin for stateless ViewModels
/// - [StateViewModel]: Abstract class for stateful ViewModels
/// - [ViewModelFactory]: Factory interface for creating ViewModels
/// - [DefaultViewModelFactory]: Default implementation of ViewModelFactory
/// - [ViewModelLifecycle]: Interface for ViewModel lifecycle callbacks
///
/// The ViewModel system provides automatic lifecycle management, dependency
/// injection, and integration with Flutter's widget system through mixins.
library;

import 'dart:async';
import 'dart:nativewrappers/_internal/vm/lib/ffi_allocation_patch.dart';

import 'package:flutter/foundation.dart';
import 'package:meta/meta.dart' show internal;
import 'package:uuid/v4.dart';
import 'package:view_model/src/devtool/service.dart';
import 'package:view_model/src/get_instance/manager.dart';
import 'package:view_model/src/get_instance/store.dart';
import 'package:view_model/src/log.dart';
import 'package:view_model/src/view_model/config.dart';

import 'dependency_handler.dart';
import 'state_store.dart';

/// A ViewModel implementation that extends Flutter's [ChangeNotifier].
///
/// This class provides compatibility with existing Flutter code that uses
/// [ChangeNotifier] while adding ViewModel capabilities. The [addListener]
/// method is overridden to use the ViewModel's [listen] method internally.
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
class ChangeNotifierViewModel extends ChangeNotifier with ViewModel {
  @override
  void addListener(VoidCallback listener) {
    listen(onChanged: listener);
  }
}

/// Base mixin class for all ViewModels in the application.
///
/// This mixin provides core functionality for ViewModels including:
/// - Lifecycle management through [InstanceLifeCycle]
/// - Listener
/// management for reactive updates
/// - Static methods for reading existing ViewModels
/// - Integration with the ViewModel system
///
/// ViewModels using this mixin are automatically managed by the system
/// and will be disposed when no longer needed.
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
mixin class ViewModel implements InstanceLifeCycle {
  late InstanceArg _instanceArg;

  /// Tracks which dependency ViewModels this ViewModel is already listening to.
  ///
  /// This map prevents duplicate listener registration when the same dependency
  /// ViewModel is accessed multiple times through [watchViewModel]. The key is
  /// the dependency ViewModel instance, and the value is always `true` when
  /// a listener is registered.
  ///
  /// This optimization ensures that:
  /// 1. Each dependency ViewModel is only listened to once
  /// 2. Avoids memory leaks from duplicate listeners
  /// 3. Improves performance by preventing redundant listener setup
  final Map<ViewModel, bool> _dependencyListeners = {};

  /// Gets the tag associated with this ViewModel instance.
  ///
  /// The tag is set by the [ViewModelFactory.getTag] method and can be used
  /// to identify or categorize ViewModel instances.
  Object? get tag => _instanceArg.tag;

  static bool _initialized = false;
  static bool _initializedDevtool = false;

  static final List<ViewModelLifecycle> _viewModelLifecycles =
      List.empty(growable: true);

  /// Attempts to read a ViewModel instance by [key] or [tag].
  ///
  /// Returns `null` if no matching ViewModel is found, unlike [readCached] which
  /// throws an exception.
  ///
  /// This method is useful for safely accessing a cached ViewModel without
  /// causing an error if it doesn't exist.
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
      return readCached(key: key, tag: tag);
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
  /// This method searches for an existing ViewModel instance using the following priority:
  /// 1. If [key] is provided, it searches by the unique key.
  /// 2. If [tag] is provided, it searches by the tag.
  /// 3. If neither is provided, it finds the most recently created instance of type [T].
  ///
  /// This method is for accessing already-created and cached ViewModels.
  /// It does not create new instances.
  ///
  /// Parameters:
  /// - [key]: The unique key from [ViewModelFactory.key].
  /// - [tag]: The tag from [ViewModelFactory.getTag].
  ///
  /// Returns the matching ViewModel instance.
  ///
  /// Throws a [StateError] if:
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
        //
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
      throw StateError("$T is disposed");
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

  final List<VoidCallback?> _listeners = [];
  static ViewModelConfig _config = ViewModelConfig();

  /// Gets the current ViewModel configuration.
  ///
  /// The configuration controls global ViewModel behavior and can be set
  /// during initialization via [initialize].
  static ViewModelConfig get config => _config;

  final _autoDisposeController = AutoDisposeController();
  bool _isDisposed = false;

  /// Returns `true` if this ViewModel has been disposed.
  ///
  /// Once disposed, the ViewModel should not be used and will throw errors
  /// if methods are called on it.
  bool get isDisposed => _isDisposed;

  /// Returns `true` if this ViewModel has any active listeners.
  ///
  /// This can be useful for determining if the ViewModel is being observed
  /// by any widgets or other components.
  bool get hasListeners => _listeners.isNotEmpty;

  /// Handler for managing ViewModel dependencies.
  /// This encapsulates all dependency-related logic and provides a clean separation of concerns.
  @internal
  final DependencyHandler dependencyHandler = DependencyHandler();

  /// Reads a dependency ViewModel from the current context.
  ///
  /// This method allows ViewModels to access other ViewModels as dependencies.
  /// The core logic is:
  /// 1. Host ViewModel first collects the dependency ViewModel configuration
  /// 2. Check if host ViewModel is already associated with a State
  /// 3. If associated, delegate to State's readViewModel/watchViewModel to register the dependency
  /// 4. If not associated, store the dependency config for later registration
  ///
  /// This ensures that dependency relationships are properly managed by the Widget State
  /// that owns the host ViewModel, maintaining consistent lifecycle management.
  ///
  /// Parameters:
  /// - [key]: Optional key to identify a specific ViewModel instance
  /// - [tag]: Optional tag for ViewModel lookup
  /// - [factory]: Optional factory for creating the ViewModel if it doesn't exist
  ///
  /// Returns the requested ViewModel instance.
  ///
  /// Example:
  /// ```dart
  /// class MyViewModel extends ViewModel {
  ///   late final UserService userService;
  ///
  ///   @override
  ///   void onInit() {
  ///     // Host ViewModel collects dependency config and delegates to State
  ///     userService = readViewModel<UserService>();
  ///   }
  /// }
  /// ```
  @protected
  T readViewModel<T extends ViewModel>({
    required ViewModelFactory<T> factory,
  }) {
    if (isDisposed) throw StateError("$T is disposed");
    return dependencyHandler.getViewModel<T>(
      factory: factory,
      listen: false,
    );
  }

  @protected
  T readCachedViewModel<T extends ViewModel>({
    Object? key,
    Object? tag,
  }) {
    if (isDisposed) throw StateError("$T is disposed");
    return dependencyHandler.getViewModel<T>(
      listen: false,
      key: key,
      tag: tag,
    );
  }

  /// Watches a dependency ViewModel of type [T] and listens for changes.
  ///
  /// Similar to [readViewModel] but automatically listens for changes in the dependency
  /// ViewModel and triggers rebuilds when the dependency changes.
  ///
  /// This method allows ViewModels to access other ViewModels as dependencies with
  /// automatic change notification. When the dependency ViewModel changes, this
  /// ViewModel will also notify its listeners.
  ///
  /// Parameters:
  /// - [key]: Optional key to identify a specific ViewModel instance
  /// - [tag]: Optional tag for ViewModel lookup
  /// - [factory]: Optional factory for creating the ViewModel if it doesn't exist
  ///
  /// Returns the requested ViewModel instance with change listening enabled.
  ///
  /// Example:
  /// ```dart
  /// class UserProfileViewModel extends ViewModel {
  ///   late final AuthViewModel authViewModel;
  ///
  ///   @override
  ///   void onInit() {
  ///     // Watch auth changes and automatically update when auth state changes
  ///     authViewModel = watchViewModel<AuthViewModel>();
  ///   }
  ///
  ///   String get displayName => authViewModel.user?.name ?? 'Guest';
  /// }
  /// ```
  @protected
  T watchViewModel<T extends ViewModel>({
    required ViewModelFactory<T> factory,
  }) {
    if (isDisposed) throw StateError("$T is disposed");
    final vm = dependencyHandler.getViewModel<T>(
      factory: factory,
      listen: true,
    );

    // Check if we're already listening to this dependency ViewModel
    // to prevent duplicate listener registration
    if (_dependencyListeners[vm] != true) {
      // Register a listener to automatically notify this ViewModel
      // when the dependency ViewModel changes
      addDispose(vm.listen(onChanged: () {
        onDependencyNotify(vm);
      }));
      // Mark this dependency as being listened to
      _dependencyListeners[vm] = true;
    }
    return vm;
  }

  @protected
  T watchCachedViewModel<T extends ViewModel>({
    Object? key,
    Object? tag,
  }) {
    if (isDisposed) throw StateError("$T is disposed");
    final vm = dependencyHandler.getViewModel<T>(
      key: key,
      tag: tag,
      listen: true,
    );

    // Check if we're already listening to this dependency ViewModel
    // to prevent duplicate listener registration
    if (_dependencyListeners[vm] != true) {
      // Register a listener to automatically notify this ViewModel
      // when the dependency ViewModel changes
      addDispose(vm.listen(onChanged: () {
        onDependencyNotify(vm);
      }));
      // Mark this dependency as being listenedto
      _dependencyListeners[vm] = true;
    }
    return vm;
  }

  /// Called when a dependency ViewModel notifies changes.
  ///
  /// This method is called when a dependency ViewModel that this ViewModel is
  /// listening to notifies changes. By default, it simply notifies listeners
  /// of this ViewModel.
  ///
  /// Parameters:
  /// - [vm]: The dependency ViewModel that notified changes
  @mustCallSuper
  @protected
  void onDependencyNotify(ViewModel vm) {}

  /// Attempts to read a dependency ViewModel of type [T].
  ///
  /// Similar to [readViewModel] but returns `null` if the dependency is not
  /// found
  /// instead of throwing an exception.
  ///
  /// Parameters:
  /// - [key]: Optional key to identify the specific dependency instance
  /// - [tag]: Optional tag to identify the specific dependency instance
  ///
  /// Returns the dependency ViewModel instance if found, otherwise `null`.
  ///
  /// Example:
  /// ```dart
  /// class OptionalFeatureViewModel with ViewModel {
  ///   String get status {
  ///     final authViewModel = maybeReadViewModel<AuthViewModel>();
  ///     return authViewModel?.isAuthenticated == true ? 'Authenticated' :
  ///     'Guest';
  ///   }
  /// }
  /// ```
  @protected
  T? maybeReadCachedViewModel<T extends ViewModel>({
    Object? key,
    Object? tag,
  }) {
    try {
      return readCachedViewModel<T>(
        key: key,
        tag: tag,
      );
    } catch (e) {
      return null;
    }
  }

  /// Attempts to watch a dependency ViewModel of type [T] with automatic change
  /// listening.
  ///
  /// This is a safe version of [watchViewModel] that returns `null` if the
  /// dependency
  /// is not found or if any error occurs during the watch operation, instead of
  /// throwing an exception.
  ///
  /// When successful, this method:
  /// 1. Retrieves the dependency ViewModel (creating it if necessary via
  ///    factory)
  /// 2. Sets up automatic listening for changes from the dependency
  /// 3. Ensures this ViewModel will be notified when the dependency changes
  /// 4. Prevents duplicate listener registration for the same dependency
  ///
  /// Parameters:
  /// - [key]: Optional key to identify the specific dependency instance
  /// - [tag]: Optional tag to identify the specific dependency instance
  /// - [factory]: Optional factory for creating the ViewModel if it doesn't
  /// exist
  ///
  /// Returns the dependency ViewModel instance if found and successfully
  /// watched,
  /// otherwise `null`.
  ///
  /// Example:
  /// ```dart
  /// class UserProfileViewModel extends ViewModel {
  ///   AuthViewModel? authViewModel;
  ///
  ///   @override
  ///   void onInit() {
  ///     // Safely watch auth changes; won't throw if AuthViewModel doesn't
  ///     exist.
  ///     _auth = maybeWatchExistingViewModel<AuthViewModel>();
  ///   }
  ///
  ///   String get displayName => _auth?.user?.name ?? 'Guest';
  /// }
  /// ```
  @protected
  T? maybeWatchCacheViewModel<T extends ViewModel>({
    Object? key,
    Object? tag,
  }) {
    try {
      return watchCachedViewModel<T>(
        key: key,
        tag: tag,
      );
    } catch (e) {
      return null;
    }
  }

  /// Removes a listener from this ViewModel.
  ///
  /// Parameters:
  /// - [listener]: The listener function to remove
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  /// Adds a dispose callback that will be executed when this ViewModel is
  /// disposed.
  ///
  /// This is useful for cleaning up resources like streams, timers, or other
  /// subscriptions that need to be disposed when the ViewModel is no longer
  /// needed.
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
  Future<void> addDispose(Function() block) async {
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
  /// Any exceptions thrown by listeners are caught and logged to prevent
  /// one listener from affecting others.
  void notifyListeners() {
    for (final element in _listeners) {
      try {
        element?.call();
      } catch (e) {
        viewModelLog("error on $e");
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
      // _viewModelLifecycles.add(DependencyTracker.instance);
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
  void onAddWatcher(InstanceArg arg, String newWatchId) {
    for (final element in _viewModelLifecycles) {
      element.onAddWatcher(this, arg, newWatchId);
    }
  }

  @protected
  @mustCallSuper
  @override
  void onRemoveWatcher(InstanceArg arg, String removedWatchId) {
    for (final element in _viewModelLifecycles) {
      element.onRemoveWatcher(this, arg, removedWatchId);
    }
  }

  @override
  @mustCallSuper
  @protected
  void onDispose(InstanceArg arg) {
    _isDisposed = true;
    _autoDisposeController.dispose();
    _dependencyListeners.clear();
    dependencyHandler.dispose();
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
/// The state is immutable - each change creates a new state instance via [setState].
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
  final List<Function(T? previous, T state)?> _stateListeners = [];

  /// Adds a state-specific listener that receives both previous and current state.
  ///
  /// Unlike the general [listen] method, this provides access to both the
  /// previous state and the new state, allowing for more granular change detection.
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

  late final T initState;
  late final StreamSubscription _streamSubscription;

  StateViewModel({required T state}) {
    initState = state;
    _store = ViewModelStateStore(
      initialState: state,
    );

    _streamSubscription = _store.stateStream.listen((event) async {
      if (_isDisposed) return;
      for (final element in _stateListeners) {
        try {
          element?.call(event.previousState, event.currentState);
        } catch (e) {
          //
        }
      }

      for (final element in _listeners) {
        try {
          element?.call();
        } catch (e) {
          //
        }
      }
    });
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
    try {
      _store.notifyListeners();
    } catch (e) {
      onError(e);
    }
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
  /// This method internally uses the `isSameState` function from
  /// [ViewModelConfig] to determine if the new state is the same as the
  /// current state. If they are considered the same, no update will be triggered.
  /// By default, this comparison is done by checking the memory addresses
  /// of the state objects using `identical()`.
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
  /// Returns `null` if no previous state exists (i.e., this is the initial state).
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
    _streamSubscription.cancel();
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
  /// Any exceptions thrown by disposal callbacks are caught and logged
  /// to prevent one callback from affecting others.
  void dispose() {
    for (final element in _disposeSet) {
      try {
        element?.call();
      } catch (e) {
        viewModelLog("AutoDisposeMixin error on $e");
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
/// class MyViewModelFactory with ViewModelFactory<MyViewModel> {
///   @override
///   MyViewModel build() => MyViewModel();
///
///   @override
///   Object? key() => 'shared-instance'; // Optional: for sharing
///
///   @override
///   Object? getTag() => 'my-tag'; // Optional: for identification
/// }
/// ```
abstract mixin class ViewModelFactory<T> {
  static final _defaultShareId = const UuidV4().generate();

  /// Returns a unique key for sharing ViewModel instances.
  ///
  /// ViewModels with the same key will be shared across different widgets.
  /// If this returns `null`, a new instance will be created each time.
  ///
  /// By default, returns a shared ID if [singleton] is `true`, otherwise
  /// `null`.
  ///
  /// Example:
  /// ```dart
  /// @override
  /// Object? key() => 'global-counter'; // Share across app
  /// ```
  Object? key() => (singleton()) ? _defaultShareId : null;

  /// Returns a tag to identify or categorize this ViewModel.
  ///
  /// Tags can be used to find ViewModels by category rather than type.
  /// The tag is accessible via [ViewModel.tag] and can be used with
  /// [ViewModel.readCached] to find ViewModels by tag.
  ///
  /// Example:
  /// ```dart
  /// @override
  /// Object? getTag() => 'user-data';
  /// ```
  Object? getTag() => null;

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

  /// Returns `true` if this factory should create singleton instances.
  ///
  /// When `true`, the factory will automatically return a shared ID as the key,
  /// ensuring only one instance of type [T] exists in the system.
  ///
  /// Example:
  /// ```dart
  /// @override
  /// bool singleton() => true; // Only one instance allowed
  /// ```
  bool singleton() => false;
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
  /// - [newWatchId]: Unique identifier for the new watcher
  void onAddWatcher(ViewModel viewModel, InstanceArg arg, String newWatchId) {}

  /// Called when a watcher is removed from a ViewModel.
  ///
  /// Parameters:
  /// - [viewModel]: The ViewModel being unwatched
  /// - [arg]: Instance arguments
  /// - [removedWatchId]: Unique identifier for the removed watcher
  void onRemoveWatcher(
      ViewModel viewModel, InstanceArg arg, String removedWatchId) {}

  /// Called when a ViewModel is disposed.
  ///
  /// Parameters:
  /// - [viewModel]: The ViewModel being disposed
  /// - [arg]: Instance arguments
  void onDispose(ViewModel viewModel, InstanceArg arg) {}
}

/// A default generic ViewModelFactory for quickly creating ViewModel factories.
class DefaultViewModelFactory<T extends ViewModel> extends ViewModelFactory<T> {
  final T Function() builder;
  late final Object? _key;
  late final Object? _tag;
  final bool isSingleton;

  DefaultViewModelFactory({
    required this.builder,
    Object? key,
    Object? tag,

    /// Whether to use singleton mode. This is just a convenient way to
    /// set a unique key for you.
    /// Note that the priority is lower than the key parameter.
    this.isSingleton = false,
  }) {
    _key = key;
    _tag = tag;
  }

  @override
  Object? key() {
    if (_key == null) {
      return super.key();
    } else {
      return _key;
    }
  }

  @override
  Object? getTag() => _tag;

  @override
  T build() => builder();

  @override
  bool singleton() => isSingleton;
}
