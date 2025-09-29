// @author luwenjie on 2025/3/25 17:24:31

/// Flutter State mixin for ViewModel integration.
///
/// This file provides the [ViewModelStateMixin] that integrates ViewModels
/// with Flutter's widget system. It handles:
/// - Automatic ViewModel lifecycle management
/// - Widget rebuilding when ViewModels change
/// - Proper disposal and cleanup
/// - Debug information for development tools
///
/// The mixin should be used with StatefulWidget's State class to enable
/// reactive ViewModel integration.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';
import 'package:uuid/v4.dart';
import 'package:view_model/src/get_instance/auto_dispose.dart';
import 'package:view_model/src/get_instance/manager.dart';
import 'package:view_model/src/get_instance/store.dart';
import 'package:view_model/src/view_model/view_model.dart';

import 'dependency_handler.dart';
import 'model.dart';

/// Mixin that integrates ViewModels with Flutter's State lifecycle.
///
/// This mixin provides methods to watch and read ViewModels from within
/// a StatefulWidget's State. It automatically handles:
/// - ViewModel creation and caching
/// - Widget rebuilding when ViewModels change
/// - Proper cleanup when the widget is disposed
/// - Debug information for development tools
///
/// Example usage:
/// ```dart
/// class MyPage extends StatefulWidget {
///   @override
///   State<MyPage> createState() => _MyPageState();
/// }
///
/// class _MyPageState extends State<MyPage> with ViewModelStateMixin<MyPage> {
///   late final MyViewModel viewModel;
///
///   @override
///   void initState() {
///     super.initState();
///     viewModel = watchViewModel<MyViewModel>(
///       factory: MyViewModelFactory(),
///     );
///   }
///
///   @override
///   Widget build(BuildContext context) {
///     return Text('Count: \${viewModel.count}');
///   }
/// }
/// ```
mixin ViewModelStateMixin<T extends StatefulWidget> on State<T> {
  late final _instanceController = AutoDisposeInstanceController(
    onRecreate: () {
      setState(() {});
    },
    watcherName: getViewModelWatcherName(),
    dependencyResolver: onChildDependencyResolver,
  );
  final Map<ViewModel, bool> _stateListeners = {};

  final _defaultViewModelKey = const UuidV4().generate();
  final List<Function()> _disposes = [];
  bool _dispose = false;

  // Cache path information to avoid repeated retrieval
  String? _cachedObjectPath;

  /// Generates a debug-friendly name for this ViewModel watcher.
  ///
  /// This method creates a unique identifier that includes the file path,
  /// line number, and class name where the ViewModel is being watched.
  /// This information is useful for debugging and development tools.
  ///
  /// Returns an empty string in release mode for performance.
  ///
  /// Example output: `lib/pages/counter_page.dart:25  _CounterPageState`
  String getViewModelWatcherName() {
    if (!kDebugMode) return "";

    final pathInfo = _getCurrentObjectPath();
    return pathInfo.isNotEmpty ? "$pathInfo  $runtimeType" : "$runtimeType";
  }

  /// Gets the file path and line number where this mixin is being used.
  ///
  /// This method analyzes the current call stack to determine the exact
  /// location where ViewModelStateMixin is being used. It handles both
  /// regular file paths and package: format paths.
  ///
  /// The result is cached to avoid repeated stack trace analysis.
  ///
  /// Returns:
  /// - In debug mode: A string like "lib/pages/counter_page.dart:25"
  /// - In release mode: An empty string
  /// - If path cannot be determined: The runtime type as fallback
  ///
  /// Example output: `lib/pages/counter_page.dart:25`
  String _getCurrentObjectPath() {
    if (!kDebugMode) return "";

    // Return cached result if available
    if (_cachedObjectPath != null) {
      return _cachedObjectPath!;
    }

    // Get current call stack
    final stackTrace = StackTrace.current;
    final frames = stackTrace.toString().split('\n');

    // Skip stack frames until we find the host class that uses ViewModelStateMixin
    for (int i = 1; i < frames.length; i++) {
      final frame = frames[i].trim();
      if (frame.isEmpty) continue;

      // Extract file path information using regex
      final match = RegExp(r'\((.+\.dart):(\d+):(\d+)\)').firstMatch(frame);
      if (match != null) {
        final filePath = match.group(1)!;
        final line = match.group(2)!;
        final fileName = filePath.split('/').last;

        // Skip frames from extension.dart itself, find the host class
        if (!fileName.contains('extension.dart')) {
          // Handle package: format paths
          String relativePath = filePath;
          if (filePath.startsWith('package:')) {
            // For package: paths, extract only the lib/ part
            final packageMatch =
                RegExp(r'package:([^/]+)/(.+)').firstMatch(filePath);
            if (packageMatch != null) {
              final pathAfterPackage = packageMatch.group(2)!;
              // If path doesn't start with lib/, add it
              if (!pathAfterPackage.startsWith('lib/')) {
                relativePath = 'lib/$pathAfterPackage';
              } else {
                relativePath = pathAfterPackage;
              }
            }
          } else {
            // For regular file paths, extract from lib/ directory
            final libIndex = filePath.indexOf('/lib/');
            if (libIndex != -1) {
              relativePath = filePath
                  .substring(libIndex + 1); // Remove leading slash, keep lib/
            }
          }

          // Return relative path and line number, cache the result
          _cachedObjectPath = "$relativePath:$line";
          return _cachedObjectPath!;
        }
      }
    }

    // Fallback to runtimeType if path cannot be retrieved
    _cachedObjectPath = "$runtimeType";
    return _cachedObjectPath!;
  }

  @override
  @mustCallSuper
  void initState() {
    super.initState();
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
  /// final userVM = watchViewModel<UserViewModel>();
  /// // Later, force recreation
  /// recycleViewModel(userVM);
  /// ```
  void recycleViewModel<VM extends ViewModel>(VM vm) {
    _instanceController.recycle(vm);
    setState(() {});
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
  /// Throws [StateError] if no matching ViewModel is found.
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
  /// This is the primary method for accessing ViewModels in widgets.
  /// It automatically handles ViewModel creation, caching, and disposal.
  /// The widget will rebuild whenever the ViewModel notifies listeners.
  ///
  /// Search priority:
  /// 1. If [key] is provided, searches for existing ViewModel by key
  /// 2. If [factory] is provided and no key match, creates new ViewModel
  /// 3. If [tag] is provided and no factory, searches by tag
  /// 4. If none provided, finds most recently created ViewModel of type [VM]
  ///
  /// Parameters:
  /// - [factory]: Factory to create the ViewModel if needed
  /// - [key]: Unique key for sharing ViewModel instances
  /// - [tag]: Tag to identify ViewModel instances
  ///
  /// Returns the ViewModel instance.
  ///
  /// Throws [StateError] if no matching ViewModel is found.
  ///
  /// Example:
  /// ```dart
  /// class MyWidget extends StatefulWidget {
  ///   @override
  ///   _MyWidgetState createState() => _MyWidgetState();
  /// }
  ///
  /// class _MyWidgetState extends State<MyWidget> with ViewModelStateMixin {
  ///   late final MyViewModel viewModel;
  ///
  ///   @override
  ///   void initState() {
  ///     super.initState();
  ///     viewModel = watchViewModel<MyViewModel>(
  ///       factory: MyViewModelFactory(),
  ///       key: 'shared-instance', // Optional
  ///     );
  ///   }
  ///
  ///   @override
  ///   Widget build(BuildContext context) {
  ///     // use viewModel here
  ///     return Container();
  ///   }
  /// }
  /// ```
  ///
  /// Note: ViewModels are automatically disposed when no widgets are watching them.
  /// Dependencies are automatically established when ViewModels call readViewModel.
  VM watchViewModel<VM extends ViewModel>({
    ViewModelFactory<VM>? factory,
    Object? key,
    Object? tag,
  }) {
    final viewModel = _getViewModel<VM>(
      factory: factory,
      arg: InstanceArg(
        key: key,
        tag: tag,
      ),
      listen: true,
    );

    return viewModel;
  }

  /// Reads a ViewModel without triggering widget rebuilds.
  ///
  /// This method provides access to a ViewModel without subscribing to its
  /// changes. Use this when you need to call methods on the ViewModel but
  /// don't want the widget to rebuild when the ViewModel changes.
  ///
  /// Search priority (same as [watchViewModel]):
  /// 1. If [key] is provided, searches for existing ViewModel by key
  /// 2. If [factory] is provided and no key match, creates new ViewModel
  /// 3. If [tag] is provided and no factory, searches by tag
  /// 4. If none provided, finds most recently created ViewModel of type [VM]
  ///
  /// Parameters:
  /// - [factory]: Factory to create the ViewModel if needed
  /// - [key]: Unique key for sharing ViewModel instances
  /// - [tag]: Tag to identify ViewModel instances
  ///
  /// Returns the ViewModel instance.
  ///
  /// Throws [StateError] if no matching ViewModel is found.
  ///
  /// Example:
  /// ```dart
  /// void _onButtonPressed() {
  ///   final vm = readViewModel<MyViewModel>();
  ///   vm.performAction(); // Won't trigger rebuild
  /// }
  /// ```
  ///
  /// Note: The ViewModel is still bound to this widget's lifecycle and will
  /// be disposed when no widgets are watching or reading it.
  /// Dependencies are automatically established when ViewModels call readViewModel.
  VM readViewModel<VM extends ViewModel>({
    ViewModelFactory<VM>? factory,
    Object? key,
    Object? tag,
  }) {
    final viewModel = _getViewModel<VM>(
      factory: factory,
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
    final tag = factory.getTag();
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

  @internal
  // ignore: avoid_shadowing_type_parameters
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
        if (context.mounted &&
            SchedulerBinding.instance.schedulerPhase !=
                SchedulerPhase.persistentCallbacks) {
          setState(() {});
        } else {
          SchedulerBinding.instance.addPostFrameCallback((_) {
            if (!_dispose && context.mounted) {
              setState(() {});
            }
          });
        }
      }));
    }
  }

  /// Attempts to watch a ViewModel, returning null if not found.
  ///
  /// This is a safe version of [watchViewModel] that returns null instead
  /// of throwing an exception when no matching ViewModel is found.
  ///
  /// Parameters:
  /// - [factory]: Factory to create the ViewModel if needed
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
  VM? maybeWatchViewModel<VM extends ViewModel>({
    ViewModelFactory<VM>? factory,
    Object? key,
    Object? tag,
  }) {
    try {
      return watchViewModel(
        factory: factory,
        key: key,
        tag: tag,
      );
    } catch (e) {
      return null;
    }
  }

  /// Attempts to read a ViewModel, returning null if not found.
  ///
  /// This is a safe version of [readViewModel] that returns null instead
  /// of throwing an exception when no matching ViewModel is found.
  ///
  /// Parameters:
  /// - [factory]: Factory to create the ViewModel if needed
  /// - [key]: Unique key for sharing ViewModel instances
  /// - [tag]: Tag to identify ViewModel instances
  ///
  /// Returns the ViewModel instance or null if not found.
  ///
  /// Example:
  /// ```dart
  /// final vm = maybeReadViewModel<MyViewModel>(key: 'optional-key');
  /// vm?.performAction(); // Safe call
  /// ```
  VM? maybeReadViewModel<VM extends ViewModel>({
    ViewModelFactory<VM>? factory,
    Object? key,
    Object? tag,
  }) {
    try {
      return readViewModel(
        factory: factory,
        key: key,
        tag: tag,
      );
    } catch (e) {
      return null;
    }
  }

  @override
  @mustCallSuper
  void dispose() {
    _dispose = true;
    _stateListeners.clear();
    _instanceController.dispose();
    for (final e in _disposes) {
      e.call();
    }
    super.dispose();
  }
}
