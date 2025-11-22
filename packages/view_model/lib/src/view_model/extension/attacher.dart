import 'package:flutter/foundation.dart';
import 'package:uuid/v4.dart';
import 'package:view_model/src/get_instance/auto_dispose.dart';
import 'package:view_model/src/get_instance/manager.dart';
import 'package:view_model/src/get_instance/store.dart';
import 'package:view_model/src/log.dart';
import 'package:view_model/src/view_model/dependency_handler.dart';
import 'package:view_model/src/view_model/interface.dart';
import 'package:view_model/src/view_model/model.dart';
import 'package:view_model/src/view_model/pause_aware.dart';
import 'package:view_model/src/view_model/view_model.dart';

///
class ViewModelAttacher implements ViewModelCreateInterface {
  bool _dispose = false;
  final Function() rebuildState;
  final String Function() getBinderName;
  final PauseAwareController pauseAwareController;

  /// Creates a [ViewModelAttacher] with the callback used to trigger rebuild
  /// when resuming.
  ViewModelAttacher({
    required this.rebuildState,
    required this.getBinderName,
    required this.pauseAwareController,
  });

  bool get isDisposed => _dispose;

  late final _instanceController = AutoDisposeInstanceController(
    onRecreate: () {
      rebuildState();
    },
    binderName: getBinderName(),
    dependencyResolver: onChildDependencyResolver,
  );
  final Map<ViewModel, bool> _stateListeners = {};
  final _defaultViewModelKey = const UuidV4().generate();
  final List<Function()> _disposes = [];

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
  /// final userVM = watchViewModel<UserViewModel>(factory:);
  /// // Later, force recreation
  /// recycleViewModel(userVM);
  /// ```
  void recycleViewModel<VM extends ViewModel>(VM vm) {
    _instanceController.recycle(vm);
    rebuildState();
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
  ///     _viewModel = watchViewModel<MyViewModel>(
  ///       factory: MyViewModelFactory(),
  ///     );
  ///   }
  ///
  ///   @override
  ///   Widget build(BuildContext context) {
  ///     return Text('Count: ${_viewModel.count}');
  ///   }
  /// }
  /// ```
  @override
  VM watchViewModel<VM extends ViewModel>({
    required ViewModelFactory<VM> factory,
  }) {
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
  /// Throws a [StateError] if no matching ViewModel is found in the cache.
  VM watchCachedViewModel<VM extends ViewModel>({
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
  /// Throws a [StateError] if the widget has been disposed.
  ///
  /// Example:
  /// ```dart
  /// void _onButtonPressed() {
  ///   final vm = readViewModel<MyViewModel>(factory: MyViewModelFactory());
  ///   vm.performAction(); // This will not trigger a rebuild.
  /// }
  /// ```
  VM readViewModel<VM extends ViewModel>({
    required ViewModelFactory<VM> factory,
  }) {
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
  /// Throws a [StateError] if no matching ViewModel is found in the cache.
  VM readCachedViewModel<VM extends ViewModel>({
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
      throw StateError("VM must extends ViewModel");
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
  /// Throws [StateError] if the widget has been disposed.
  VM _createViewModel<VM extends ViewModel>({
    required ViewModelFactory<VM> factory,
    bool listen = true,
  }) {
    if (_dispose) {
      throw StateError("state is disposed");
    }
    final Object key = factory.key() ?? _defaultViewModelKey;
    final tag = factory.tag();
    final res = runWithResolver(
      () {
        return _instanceController.getInstance<VM>(
          factory: InstanceFactory<VM>(
            arg: InstanceArg(
              key: key,
              tag: tag,
            ),
            builder: factory.build,
          ),
        )..dependencyHandler.addDependencyResolver(onChildDependencyResolver);
      },
      onChildDependencyResolver,
    );

    if (listen) {
      _addListener(res);
    }
    return res;
  }

  // ignore: avoid_shadowing_type_parameters
  @internal
  T onChildDependencyResolver<T extends ViewModel>({
    required ViewModelDependencyConfig<T> dependency,
    bool listen = true,
  }) {
    final childViewModel = _getViewModel<T>(
      factory: dependency.config.factory,
      arg: InstanceArg(
        key: dependency.config.key,
        tag: dependency.config.tag,
      ),
      listen: listen,
    );
    childViewModel.dependencyHandler
        .addDependencyResolver(onChildDependencyResolver);
    return childViewModel;
  }

  bool _hasMissedUpdates = false;
  bool get hasMissedUpdates => _hasMissedUpdates;

  void consumeMissedUpdates() {
    _hasMissedUpdates = false;
  }

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
        if (pauseAwareController.isPaused) {
          _hasMissedUpdates = true;
          viewModelLog(
            "${getBinderName()} is paused, delay rebuild",
          );
          return;
        }
        rebuildState();
      }));
    }
  }

  /// Attempts to watch a ViewModel, returning null if not found.
  ///
  /// This is a safe version of [watchCachedViewModel] that returns null instead
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
  /// final vm = maybeWatchViewModel<MyViewModel>(key: 'optional-key');
  /// if (vm != null) {
  ///   // Use the ViewModel
  /// }
  /// ```
  VM? maybeWatchCachedViewModel<VM extends ViewModel>({
    Object? key,
    Object? tag,
  }) {
    try {
      return watchCachedViewModel(
        key: key,
        tag: tag,
      );
    } catch (e) {
      return null;
    }
  }

  /// Safe read for a cached ViewModel without listening.
  /// Returns `null` instead of throwing when no matching instance
  /// is found by `key` or `tag`.
  VM? maybeReadCachedViewModel<VM extends ViewModel>({
    Object? key,
    Object? tag,
  }) {
    try {
      return readCachedViewModel(
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
  void attach() {}

  @mustCallSuper
  void dispose() {
    _dispose = true;
    _stateListeners.clear();
    _instanceController.dispose();
    for (final e in _disposes) {
      e.call();
    }
  }
}
