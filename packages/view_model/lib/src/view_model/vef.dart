library;

import 'package:flutter/foundation.dart';
// ignore: unnecessary_import
import 'package:meta/meta.dart' show internal;
import 'package:view_model/src/get_instance/auto_dispose.dart';
import 'package:view_model/src/get_instance/manager.dart';
import 'package:view_model/src/get_instance/store.dart';
import 'package:view_model/src/log.dart';
import 'package:view_model/src/view_model/pause_aware.dart';
import 'package:view_model/src/view_model/pause_provider.dart';
import 'package:view_model/src/view_model/util.dart';
import 'package:view_model/src/view_model/vef_zone.dart';
import 'package:view_model/src/view_model/view_model.dart';
import 'package:view_model/src/view_model/widget_mixin/stateful_extension.dart';
import 'package:view_model/src/view_model/widget_mixin/stateless_extension.dart';

import 'state_store.dart';

/// Interface that exposes helpers to access ViewModels from widgets.
///
/// Provides methods to create or fetch ViewModels, optionally listening
/// to their changes to rebuild the widget. All methods are generic on
/// `VM extends ViewModel`.
abstract interface class VefInterface {
  /// Creates or fetches a `VM` and listens for its changes.
  ///
  /// Requires a `factory` to build the instance when absent. The widget
  /// will rebuild whenever the ViewModel notifies its listeners.
  VM watch<VM extends ViewModel>(ViewModelFactory<VM> factory);

  /// Fetches an existing `VM` by `key` or `tag` and listens for changes.
  ///
  /// Does not create new instances. The widget will rebuild when the
  /// ViewModel notifies listeners.
  VM watchCached<VM extends ViewModel>({
    Object? key,
    Object? tag,
  });

  /// Creates or fetches a `VM` without listening for changes.
  ///
  /// Use this to call methods or read properties without triggering a
  /// widget rebuild.
  VM read<VM extends ViewModel>(ViewModelFactory<VM> factory);

  /// Reads an existing `VM` by `key` or `tag` without listening.
  ///
  /// Does not create new instances and does not cause the widget to
  /// rebuild when the ViewModel changes.
  VM readCached<VM extends ViewModel>({
    Object? key,
    Object? tag,
  });

  /// Safe version of `watchCached` that returns `null` when not
  /// found.
  ///
  /// Useful when a ViewModel might be optional and absence should not
  /// throw.
  VM? maybeWatchCached<VM extends ViewModel>({
    Object? key,
    Object? tag,
  });

  /// Safe version of `readCached` that returns `null` when not
  /// found.
  ///
  /// Reads the cached ViewModel without listening and avoids throwing
  /// when the instance does not exist.
  VM? maybeReadCached<VM extends ViewModel>({
    Object? key,
    Object? tag,
  });

  /// Listens to a `VM` built by the given factory.
  ///
  /// Returns a disposer to stop listening.
  void listen<VM extends ViewModel>(
    ViewModelFactory<VM> factory, {
    required VoidCallback onChanged,
  });

  void listenState<VM extends StateViewModel<S>, S>(
    ViewModelFactory<VM> factory, {
    required Function(S? previous, S state) onChanged,
  });

  void listenStateSelect<VM extends StateViewModel<S>, S, R>(
    ViewModelFactory<VM> factory, {
    required R Function(S state) selector,
    required Function(R? previous, R current) onChanged,
  });

  void recycle<VM extends ViewModel>(VM viewModel);
}

/// Core abstraction for managing ViewModel lifecycle and dependency
/// injection.
///
/// [ViewModelRef] is the foundation of the `view_model` library. It provides a
/// generic mechanism for hosting and managing ViewModels independent of
/// Flutter widgets. It can be mixed into any Dart class to gain ViewModel
/// management capabilities.
///
/// ## Core Responsibilities
///
/// - **Lifecycle Management**: Automatically creates, caches, and disposes
///   ViewModels based on reference counting
/// - **Dependency Injection**: Resolves ViewModel dependencies using
///   Zone-based dependency resolution
/// - **Pause/Resume**: Manages pause/resume lifecycle through
/// - **Pause/Resume**: Manages pause/resume lifecycle through
///   [VefPauseProvider]s
/// - **Update Notifications**: Provides [onUpdate] hook for responding to
///   ViewModel changes
///
/// ## Key Concepts
///
/// - **ViewModelRef**: Generic ViewModel manager usable in any Dart class
/// - **WidgetVef**: Specialized subclass for Flutter widgets that bridges
///   [onUpdate] to `setState`
/// - **Reference Counting**: ViewModels stay alive while at least one binder
///   watches them
///
/// ## Use Cases
///
/// 1. **Background Services**: Run ViewModel logic in background tasks
///    (e.g., downloads, data sync)
/// 2. **Pure Dart Tests**: Test ViewModel interactions without `testWidgets`
/// 3. **Global Singletons**: Manage global ViewModels before app starts
/// 4. **Widget Integration**: Used internally by [ViewModelStateMixin] and
///    [ViewModelStatelessMixin]
///
/// ## Lifecycle Hooks
///
/// Override these methods to customize behavior:
/// - [onUpdate]: Called when any watched ViewModel notifies changes
/// - [onPause]: Called when the binder is paused (e.g., widget not visible)
/// - [onResume]: Called when the binder resumes (e.g., widget becomes visible)
///
/// ## Example: Custom Service Vef
///
/// ```dart
/// class DownloadService with ViewModelRef {
///   late final DownloadViewModel _downloadVM;
///
///   DownloadService() {
///     _downloadVM = vef.watch(DownloadViewModelFactory());
///   }
///
///   @override
///   void onUpdate() {
///     // Handle ViewModel updates (e.g., update notification)
///     print("Download progress: ${_downloadVM.progress}");
///   }
///
///   void start() {
///     _downloadVM.startQueue();
///   }
///
///   @override
///   void dispose() {
///     super.dispose(); // Automatically disposes all watched ViewModels
///   }
/// }
/// ```
///
/// ## Example: Pure Dart Testing
///
/// ```dart
/// test('Test ViewModel interactions', () {
///   final ref = ViewModelRef();
///   final vm = vef.watch(MyViewModelFactory());
///
///   expect(vm.count, 0);
///   vm.increment();
///   expect(vm.count, 1);
///
///   vef.dispose(); // Clean up
/// });
/// ```
///
/// See also:
/// - [WidgetVef]: Specialized implementation for Flutter widgets
/// - [ViewModelStateMixin]: Mixin that uses ViewModelRef for StatefulWidget
/// - [VefPauseProvider]: Interface for pause/resume providers
mixin class Vef implements VefInterface {
  @protected
  // ignore: avoid_returning_this
  Vef get vef => this;
  bool _dispose = false;
  final _stackPathLocator = StackPathLocator();

  late final PauseAwareController _pauseAwareController =
      createPauseController();

  bool get isDisposed => _dispose;

  late final _instanceController = AutoDisposeInstanceController(
    onRecreate: onUpdate,
    binderName: getBinderName(),
    ref: this,
  );
  final Map<ViewModel, bool> _stateListeners = {};
  final _defaultViewModelKey = Object();
  final List<Function()> _disposes = [];

  /// Called when any watched ViewModel notifies changes.
  ///
  /// Override this method to respond to ViewModel state changes. For example,
  /// [WidgetBinder] overrides this to call `setState()` and trigger widget
  /// rebuilds.
  ///
  /// This method is called automatically when:
  /// - A watched ViewModel calls `notifyListeners()`
  /// - The binder resumes from pause with missed updates
  ///
  /// Example:
  /// ```dart
  /// @override
  /// void onUpdate() {
  ///   super.onUpdate();
  ///   // Custom logic, e.g., update UI, send notifications
  ///   print("ViewModel updated");
  /// }
  /// ```
  @mustCallSuper
  @protected
  void onUpdate() {}

  /// Called when the binder is paused.
  /// Override this to handle pause events.
  @protected
  @mustCallSuper
  void onPause() {}

  /// Called when the binder is resumed.
  /// Override this to handle resume events.
  @protected
  @mustCallSuper
  void onResume() {
    if (_hasMissedUpdates) {
      _hasMissedUpdates = false;
      onUpdate();
      viewModelLog("${getBinderName()} Resume with missed updates, updated");
    }
  }

  /// Creates the PauseAwareController for this binder.
  /// Override this to provide custom pause providers.
  PauseAwareController createPauseController() {
    return PauseAwareController(
      onWidgetPause: onPause,
      onWidgetResume: onResume,
      providers: [],
      disposableProviders: [],
      binderName: getBinderName,
    );
  }

  /// Returns true if the binder is currently paused.
  bool get isPaused => _pauseAwareController.isPaused;

  /// Generates a debug-friendly name for this ViewModel watcher.
  ///
  /// This method creates a unique identifier that includes the file path, line
  /// number, and class name where the ViewModel is being watched. This
  /// information is useful for debugging and development tools.
  ///
  /// Returns an empty string in release mode for performance.
  ///
  /// Example output: `lib/pages/counter_page.dart:25  _CounterPageState`
  String getBinderName() {
    if (!kDebugMode) return "$runtimeType";

    final pathInfo = _stackPathLocator.getCurrentObjectPath();
    return pathInfo.isNotEmpty ? "$pathInfo#$runtimeType" : "$runtimeType";
  }

  /// Forces disposal of a ViewModel and removes it from cache.
  ///
  /// This method manually disposes a ViewModel instance and triggers
  /// a widget rebuild. Use this when you need to force recreation
  /// of a ViewModel (e.g., after a logout or data reset).
  ///
  /// Parameters:
  /// - [vm]: The ViewModel instance to dispose and remove
  ///
  /// Example:
  /// ```dart
  /// var userVM = vef.watch(fac);
  /// // Later, force recreation
  /// vef.recycle(userVM);
  ///
  /// recreate new instance
  /// userVM = vef.watch(fac);
  /// ```
  void recycle<VM extends ViewModel>(VM vm) {
    _instanceController.recycle(vm);
    onUpdate();
  }

  /// Gets an existing ViewModel by key or throws an error if not found.
  ///
  /// This is an internal method that retrieves a ViewModel from the cache.
  /// If [listen] is true, the widget will rebuild when the ViewModel changes.
  ///
  /// Parameters:
  /// - [listen]: Whether to listen for ViewModel changes
  /// - [arg]: Instance arguments containing key/tag information
  ///
  /// Throws [ViewModelError] if no matching ViewModel is found.
  VM _requireExistingViewModel<VM extends ViewModel>({
    bool listen = true,
    InstanceArg arg = const InstanceArg(),
  }) {
    final res = _instanceController.getInstance<VM>(
      factory: InstanceFactory(
        arg: arg,
      ),
    );

    if (listen) {
      _addListener(res);
    }
    return res;
  }

  /// Watches a ViewModel and rebuilds the widget when it changes.
  ///
  /// This is the primary method for accessing ViewModels in a widget.
  /// It ensures that the widget rebuilds whenever the ViewModel
  /// notifies its listeners.
  ///
  /// If the ViewModel is not already in the cache, it will be created
  /// using the provided [factory]. The lifecycle of the ViewModel is
  /// automatically managed and tied to the widget's lifecycle.
  ///
  /// Parameters:
  /// - [factory]: A [ViewModelFactory] required for creating the ViewModel if
  ///   it doesn't exist.
  ///
  /// Returns the ViewModel instance.
  ///
  /// Throws a [ViewModelError] if the widget has been disposed.
  ///
  /// Example:
  /// ```dart
  /// class _MyWidgetState extends State<MyWidget> with ViewModelStateMixin {
  ///   late final MyViewModel _viewModel;
  ///
  ///   @override
  ///   void initState() {
  ///     super.initState();
  ///     _viewModel = vef.watch(MyViewModelFactory());
  ///   }
  ///
  ///   @override
  ///   Widget build(BuildContext context) {
  ///     return Text('Count: ${_viewModel.count}');
  ///   }
  /// }
  /// ```
  VM watch<VM extends ViewModel>(
    ViewModelFactory<VM> factory,
  ) {
    final viewModel = _getViewModel<VM>(
      factory: factory,
      listen: true,
    );

    return viewModel;
  }

  /// Watches a cached ViewModel and rebuilds the widget when it changes.
  ///
  /// This method retrieves an already-created ViewModel from the cache using
  /// its [key] or [tag]. It does not create new instances.
  ///
  /// The widget will rebuild whenever the ViewModel notifies its listeners.
  ///
  /// Parameters:
  /// - [key]: The unique key used to find the ViewModel.
  /// - [tag]: The tag used to find the ViewModel.
  ///
  /// Returns the cached ViewModel instance.
  ///
  /// Throws a [ViewModelError] if no matching ViewModel is found in the cache.
  VM watchCached<VM extends ViewModel>({
    Object? key,
    Object? tag,
  }) {
    final viewModel = _getViewModel<VM>(
      arg: InstanceArg(
        key: key,
        tag: tag,
      ),
      listen: true,
    );

    return viewModel;
  }

  /// Reads a ViewModel without listening for its changes.
  ///
  /// This method is used to access a ViewModel to call its methods or read its
  /// properties without causing the widget to rebuild when the
  /// ViewModel changes.
  ///
  /// If the ViewModel is not already in the cache, it will be created using
  /// the provided [factory].
  ///
  /// Parameters:
  /// - [factory]: A [ViewModelFactory] required for creating the ViewModel if
  ///   it doesn't exist.
  ///
  /// Returns the ViewModel instance.
  ///
  /// Throws a [ViewModelError] if the widget has been disposed.
  ///
  /// Example:
  /// ```dart
  /// void _onButtonPressed() {
  ///   final vm = vef.read(MyViewModelFactory());
  ///   vm.performAction(); // This will not trigger a rebuild.
  /// }
  /// ```
  VM read<VM extends ViewModel>(
    ViewModelFactory<VM> factory,
  ) {
    final viewModel = _getViewModel<VM>(
      factory: factory,
      listen: false,
    );

    return viewModel;
  }

  /// Reads a cached ViewModel without listening for its changes.
  ///
  /// This method retrieves an already-created ViewModel from the cache using
  /// its [key] or [tag]. It does not create new instances and does not cause
  /// the widget to rebuild when the ViewModel changes.
  ///
  /// Parameters:
  /// - [key]: The unique key used to find the ViewModel.
  /// - [tag]: The tag used to find the ViewModel.
  ///
  /// Returns the cached ViewModel instance.
  ///
  /// Throws a [ViewModelError] if no matching ViewModel is found in the cache.
  VM readCached<VM extends ViewModel>({
    Object? key,
    Object? tag,
  }) {
    final viewModel = _getViewModel<VM>(
      arg: InstanceArg(
        key: key,
        tag: tag,
      ),
      listen: false,
    );

    return viewModel;
  }

  VM _getViewModel<VM extends ViewModel>({
    ViewModelFactory<VM>? factory,
    InstanceArg arg = const InstanceArg(),
    bool listen = true,
  }) {
    if (VM == ViewModel || VM == dynamic) {
      throw ViewModelError("VM must extends ViewModel");
    }
    // find key first to reuse
    if (arg.key != null) {
      try {
        return _requireExistingViewModel<VM>(
          arg: InstanceArg(
            key: arg.key,
          ),
          listen: listen,
        );
      } catch (e) {
        // rethrow if factory is null and tag is null
        if (factory == null && arg.tag == null) {
          rethrow;
        }
      }
    }

    // factory
    if (factory != null) {
      return _createViewModel<VM>(
        factory: factory,
        listen: listen,
      );
    }

    // fallback to find newly created by tag
    return _requireExistingViewModel<VM>(
        arg: InstanceArg(
          tag: arg.tag,
        ),
        listen: listen);
  }

  /// Creates a new ViewModel using the provided factory.
  ///
  /// This internal method handles ViewModel creation and caching.
  /// If [listen] is true, the widget will rebuild when the ViewModel changes.
  /// Sets up dependency resolver callback to support multi-level dependencies.
  ///
  /// Parameters:
  /// - [factory]: The factory to create the ViewModel
  /// - [listen]: Whether to listen for ViewModel changes
  ///
  /// Returns the created ViewModel instance.
  ///
  /// Throws [ViewModelError] if the widget has been disposed.
  VM _createViewModel<VM extends ViewModel>({
    required ViewModelFactory<VM> factory,
    bool listen = true,
  }) {
    if (_dispose) {
      throw ViewModelError("state is disposed");
    }
    final Object key = factory.key() ?? _defaultViewModelKey;
    final tag = factory.tag();
    final res = runWithVef(
      () {
        return _instanceController.getInstance<VM>(
          factory: InstanceFactory<VM>(
            arg: InstanceArg(
              key: key,
              tag: tag,
            ),
            builder: factory.build,
          ),
        )..refHandler.addRef(vef);
      },
      vef,
    );

    if (listen) {
      _addListener(res);
    }
    return res;
  }

  bool _hasMissedUpdates = false;

  /// Adds a listener to a ViewModel for automatic widget rebuilding.
  ///
  /// This internal method sets up the connection between a ViewModel and
  /// the widget's setState method. It ensures that the widget rebuilds
  /// when the ViewModel notifies listeners.
  ///
  /// The method includes safety checks to prevent rebuilds after disposal
  /// and waits for the widget to be mounted before triggering rebuilds.
  ///
  /// Parameters:
  /// - [res]: The ViewModel to listen to
  void _addListener(ViewModel res) {
    if (_stateListeners[res] != true) {
      _stateListeners[res] = true;
      _disposes.add(res.listen(onChanged: () async {
        if (_dispose) return;
        // When paused, ignore updates; we'll blindly refresh on resume.
        if (_pauseAwareController.isPaused) {
          _hasMissedUpdates = true;
          viewModelLog(
            "${getBinderName()} is paused, delay rebuild",
          );
          return;
        }
        onUpdate();
      }));
    }
  }

  /// Attempts to watch a ViewModel, returning null if not found.
  ///
  /// This is a safe version of [watchCached] that returns null instead
  /// of throwing an exception when no matching ViewModel is found.
  ///
  /// Parameters:
  /// - [key]: Unique key for sharing ViewModel instances
  /// - [tag]: Tag to identify ViewModel instances
  ///
  /// Returns the ViewModel instance or null if not found.
  ///
  /// Example:
  /// ```dart
  /// final vm = vef.maybeWatchCached<MyViewModel>(key: 'optional-key');
  /// if (vm != null) {
  ///   // Use the ViewModel
  /// }
  /// ```
  VM? maybeWatchCached<VM extends ViewModel>({
    Object? key,
    Object? tag,
  }) {
    try {
      return watchCached(
        key: key,
        tag: tag,
      );
    } catch (e) {
      return null;
    }
  }

  /// Executes an action for all created ViewModels.
  @internal
  void performForAllViewModels(void Function(ViewModel viewModel) action) {
    _instanceController.performForAllInstances(action);
  }

  /// Called when the host widget or element attaches to the tree.
  /// Reserved for future setup steps. No-op currently.
  void init() {}

  void unbind(Object viewModel) {
    _instanceController.unbindInstance(viewModel);
  }

  void addPauseProvider(VefPauseProvider provider) {
    _pauseAwareController.addProvider(provider);
  }

  void removePauseProvider(VefPauseProvider provider) {
    _pauseAwareController.removeProvider(provider);
  }

  @mustCallSuper
  void dispose() {
    _dispose = true;
    _stateListeners.clear();
    _pauseAwareController.dispose();
    _instanceController.dispose();
    for (final e in _disposes) {
      e.call();
    }
  }

  @override
  void listen<VM extends ViewModel>(
    ViewModelFactory<VM> factory, {
    required VoidCallback onChanged,
  }) {
    _disposes.add(vef.read(factory).listen(onChanged: onChanged));
  }

  @override
  void listenState<VM extends StateViewModel<S>, S>(
    ViewModelFactory<VM> factory, {
    required Function(S? previous, S state) onChanged,
  }) {
    final VM vm = vef.read<VM>(factory);
    _disposes.add(vm.listenState(onChanged: onChanged));
  }

  @override
  void listenStateSelect<VM extends StateViewModel<S>, S, R>(
    ViewModelFactory<VM> factory, {
    required R Function(S state) selector,
    required Function(R? previous, R current) onChanged,
  }) {
    final VM vm = vef.read<VM>(factory);
    _disposes
        .add(vm.listenStateSelect(onChanged: onChanged, selector: selector));
  }

  @override
  VM? maybeReadCached<VM extends ViewModel>({Object? key, Object? tag}) {
    try {
      return readCached(key: key, tag: tag);
    } catch (e) {
      //
      return null;
    }
  }
}

extension StateRefExtension on ViewModelStateMixin {
  VM watchViewModel<VM extends ViewModel>(
      {required ViewModelFactory<VM> factory}) {
    // ignore: invalid_use_of_protected_member
    return vef.watch<VM>(factory);
  }

  VM readViewModel<VM extends ViewModel>(
      {required ViewModelFactory<VM> factory}) {
    // ignore: invalid_use_of_protected_member
    return vef.read<VM>(factory);
  }

  VM readCachedViewModel<VM extends ViewModel>({
    Object? key,
    Object? tag,
  }) {
    // ignore: invalid_use_of_protected_member
    return vef.readCached<VM>(
      key: key,
      tag: tag,
    );
  }

  VM watchCachedViewModel<VM extends ViewModel>({
    Object? key,
    Object? tag,
  }) {
    // ignore: invalid_use_of_protected_member
    return vef.watchCached<VM>(
      key: key,
      tag: tag,
    );
  }

  VM? maybeWatchCachedViewModel<VM extends ViewModel>({
    Object? key,
    Object? tag,
  }) {
    // ignore: invalid_use_of_protected_member
    return vef.maybeWatchCached<VM>(
      key: key,
      tag: tag,
    );
  }

  VM? maybeReadCachedViewModel<VM extends ViewModel>({
    Object? key,
    Object? tag,
  }) {
    // ignore: invalid_use_of_protected_member
    return vef.maybeReadCached<VM>(
      key: key,
      tag: tag,
    );
  }
}

extension StatelessWidgetRefExtension on ViewModelStatelessMixin {
  VM watchViewModel<VM extends ViewModel>(
      {required ViewModelFactory<VM> factory}) {
    // ignore: invalid_use_of_protected_member
    return vef.watch<VM>(factory);
  }

  VM readViewModel<VM extends ViewModel>(
      {required ViewModelFactory<VM> factory}) {
    // ignore: invalid_use_of_protected_member
    return vef.read<VM>(factory);
  }

  VM readCachedViewModel<VM extends ViewModel>({
    Object? key,
    Object? tag,
  }) {
    // ignore: invalid_use_of_protected_member
    return vef.readCached<VM>(
      key: key,
      tag: tag,
    );
  }

  VM watchCachedViewModel<VM extends ViewModel>({
    Object? key,
    Object? tag,
  }) {
    // ignore: invalid_use_of_protected_member
    return vef.watchCached<VM>(
      key: key,
      tag: tag,
    );
  }

  VM? maybeWatchCachedViewModel<VM extends ViewModel>({
    Object? key,
    Object? tag,
  }) {
    // ignore: invalid_use_of_protected_member
    return vef.maybeWatchCached<VM>(
      key: key,
      tag: tag,
    );
  }

  VM? maybeReadCachedViewModel<VM extends ViewModel>({
    Object? key,
    Object? tag,
  }) {
    // ignore: invalid_use_of_protected_member
    return vef.maybeReadCached<VM>(
      key: key,
      tag: tag,
    );
  }
}

extension ViewModelRefExtension on ViewModel {
  VM watchViewModel<VM extends ViewModel>(
      {required ViewModelFactory<VM> factory}) {
    // ignore: invalid_use_of_protected_member
    return vef.watch<VM>(factory);
  }

  VM readViewModel<VM extends ViewModel>(
      {required ViewModelFactory<VM> factory}) {
    // ignore: invalid_use_of_protected_member
    return vef.read<VM>(factory);
  }

  VM readCachedViewModel<VM extends ViewModel>({
    Object? key,
    Object? tag,
  }) {
    // ignore: invalid_use_of_protected_member
    return vef.readCached<VM>(
      key: key,
      tag: tag,
    );
  }

  VM watchCachedViewModel<VM extends ViewModel>({
    Object? key,
    Object? tag,
  }) {
    // ignore: invalid_use_of_protected_member
    return vef.watchCached<VM>(
      key: key,
      tag: tag,
    );
  }

  VM? maybeWatchCachedViewModel<VM extends ViewModel>({
    Object? key,
    Object? tag,
  }) {
    // ignore: invalid_use_of_protected_member
    return vef.maybeWatchCached<VM>(
      key: key,
      tag: tag,
    );
  }

  VM? maybeReadCachedViewModel<VM extends ViewModel>({
    Object? key,
    Object? tag,
  }) {
    // ignore: invalid_use_of_protected_member
    return vef.maybeReadCached<VM>(
      key: key,
      tag: tag,
    );
  }
}
