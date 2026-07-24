library;

import 'package:flutter/foundation.dart';
// ignore: unnecessary_import
import 'package:meta/meta.dart' show internal;
import 'package:view_model/src/get_instance/auto_dispose.dart';
import 'package:view_model/src/get_instance/manager.dart';
import 'package:view_model/src/get_instance/store.dart';
import 'package:view_model/src/log.dart';
import 'package:view_model/src/view_model/binding_zone.dart';
import 'package:view_model/src/view_model/pause_aware.dart';
import 'package:view_model/src/view_model/pause_provider.dart';
import 'package:view_model/src/view_model/util.dart';
import 'package:view_model/src/view_model/config.dart';
import 'package:view_model/src/view_model/view_model.dart';

import 'state_store.dart';

class _BindingSubscription {
  _BindingSubscription({
    required ViewModel viewModel,
    required this.attach,
  }) : _viewModel = viewModel {
    _remove = attach(viewModel);
  }

  ViewModel _viewModel;
  final Function() Function(ViewModel viewModel) attach;
  late Function() _remove;
  bool _disposed = false;

  bool isAttachedTo(ViewModel viewModel) => identical(_viewModel, viewModel);

  void moveTo(ViewModel viewModel) {
    if (_disposed || identical(_viewModel, viewModel)) return;
    _remove.call();
    _viewModel = viewModel;
    _remove = attach(viewModel);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _remove.call();
  }
}

/// Interface that exposes helpers to access ViewModels from widgets.
///
/// `ViewModelBinding` connects the ViewModel system with the Widget tree.
///
/// Provides methods to create or fetch ViewModels, optionally listening
/// to their changes to rebuild the widget. All methods are generic on
/// `VM extends ViewModel`.
abstract interface class ViewModelBindingInterface {
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
  ///
  /// 常规业务代码应优先使用 [read] 或 [watch] 配合 spec 精确获取。明确的
  /// `key` 可唯一定位缓存；`tag` 可能对应多个实例，应使用
  /// [readCachesByTag]。若 `key`、`tag` 都不传，多实例场景会按创建顺序返回
  /// 最新实例，仅应在明确理解该行为时使用。
  VM readCached<VM extends ViewModel>({
    Object? key,
    Object? tag,
  });

  /// Fetches all existing `VM` instances with the given `tag` and listens for
  /// their changes.
  ///
  /// Does not create new instances. The binding will rebuild when any matched
  /// ViewModel notifies listeners.
  List<VM> watchCachesByTag<VM extends ViewModel>(Object tag);

  /// Reads all existing `VM` instances with the given `tag` without listening.
  ///
  /// Does not create new instances. Matched ViewModels still bind to the
  /// current binding for lifecycle cleanup, but their `notifyListeners()`
  /// calls do not trigger rebuilds.
  List<VM> readCachesByTag<VM extends ViewModel>(Object tag);

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
  ///
  /// 常规业务代码应优先使用 [read] 或 [watch] 配合 spec 精确获取。明确的
  /// `key` 可唯一定位缓存；`tag` 多结果请使用 [readCachesByTag]。若 `key`、
  /// `tag` 都不传，多实例场景会依赖创建顺序返回最新实例，仅应在明确理解该
  /// 行为时使用。
  VM? maybeReadCached<VM extends ViewModel>({
    Object? key,
    Object? tag,
  });

  /// Listens to a `VM` built by the given factory.
  ///
  /// The listener is automatically cleaned up when this binding is disposed.
  /// For a manual disposer, call `ViewModel.listen(...)` on the instance.
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

  /// Danger: force-disposes the shared instance and removes every owner,
  /// including owners in other widgets or bindings. This also disposes an
  /// `aliveForever` instance. Do not use this as a routine lifecycle API;
  /// call it only when the global effect is intentional and understood.
  ///
  /// Every consumer must resolve the ViewModel through a getter rather than
  /// retaining it in a field. After recycling, the old object is disposed;
  /// the next getter evaluation follows the normal cache-miss creation path.
  void recycle<VM extends ViewModel>(VM viewModel);
}

/// 可选能力：在保留现有 binding 关系的前提下替换 [ViewModel] 实例。
///
/// 该能力独立于 [ViewModelBindingInterface]，避免给已有的自定义 binding 实现
/// 增加新的抽象成员。使用方仍可通过
/// [ViewModelBindingCapabilityExtension.recreate] 调用；不支持该能力的自定义
/// binding 会抛出 [UnsupportedError]。
abstract interface class ViewModelBindingRecreateCapability {
  VM recreate<VM extends ViewModel>(
    VM viewModel, {
    VM Function()? builder,
  });
}

/// 可选能力：为 selector 提供强类型的自定义相等判断。
///
/// 独立能力接口用于保持 [ViewModelBindingInterface.listenStateSelect] 的旧签名
/// 不变，使已有的 `implements ViewModelBindingInterface` 实现继续兼容。
abstract interface class ViewModelBindingStateSelectEqualsCapability {
  void listenStateSelectWithEquals<VM extends StateViewModel<S>, S, R>(
    ViewModelFactory<VM> factory, {
    required R Function(S state) selector,
    required bool Function(R previous, R current) equals,
    required Function(R? previous, R current) onChanged,
  });
}

/// 通过基础 binding 接口访问新增的可选能力。
extension ViewModelBindingCapabilityExtension on ViewModelBindingInterface {
  /// Replaces [viewModel] while preserving its active binding relationships.
  VM recreate<VM extends ViewModel>(
    VM viewModel, {
    VM Function()? builder,
  }) {
    final binding = this;
    if (binding is ViewModelBindingRecreateCapability) {
      // 使用 capability 静态类型调用实例成员，避免再次解析到当前 extension。
      final capability = binding as ViewModelBindingRecreateCapability;
      return capability.recreate<VM>(viewModel, builder: builder);
    }
    throw UnsupportedError(
      '${binding.runtimeType} does not support ViewModel recreation.',
    );
  }

  /// 使用强类型 [equals] 判断 selector 的前后值是否相等。
  void listenStateSelectWithEquals<VM extends StateViewModel<S>, S, R>(
    ViewModelFactory<VM> factory, {
    required R Function(S state) selector,
    required bool Function(R previous, R current) equals,
    required Function(R? previous, R current) onChanged,
  }) {
    final binding = this;
    if (binding is ViewModelBindingStateSelectEqualsCapability) {
      // 使用 capability 静态类型调用实例成员，避免再次解析到当前 extension。
      final capability = binding as ViewModelBindingStateSelectEqualsCapability;
      capability.listenStateSelectWithEquals<VM, S, R>(
        factory,
        selector: selector,
        equals: equals,
        onChanged: onChanged,
      );
      return;
    }
    throw UnsupportedError(
      '${binding.runtimeType} does not support custom selector equality.',
    );
  }
}

/// Common host interface for types exposing a [viewModelBinding] accessor.
///
/// This enables shared extension methods across different host types, such as
/// [ViewModel], [ViewModelStateMixin], and [ViewModelStatelessMixin].
abstract interface class ViewModelBindingHost {
  ViewModelBindingInterface get viewModelBinding;
}

/// Core abstraction for managing ViewModel lifecycle and dependency
/// injection.
///
/// [ViewModelBinding] is the foundation of the
/// `view_model` library. It provides a
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
///   [ViewModelBindingPauseProvider]s
/// - **Update Notifications**: Provides [onUpdate] hook for responding to
///   ViewModel changes
///
/// ## Key Concepts
///
/// - **ViewModelBinding**: Generic ViewModel manager usable in any Dart class
/// - **WidgetViewModelBinding**: Specialized subclass
///   for Flutter widgets that bridges
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
/// ## Example: Custom Service Binding
///
/// ```dart
/// class DownloadService with ViewModelBinding {
///   DownloadViewModel get _downloadVM =>
///       viewModelBinding.watch(DownloadViewModelSpec());
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
///   final viewModelBinding = ViewModelBinding();
///   final vm = viewModelBinding.watch(MyViewModelSpec());
///
///   expect(vm.count, 0);
///   vm.increment();
///   expect(vm.count, 1);
///
///   viewModelBinding.dispose(); // Clean up
/// });
/// ```
///
/// See also:
/// - [WidgetViewModelBinding]: Specialized implementation for Flutter widgets
/// - [ViewModelStateMixin]: Mixin that uses ViewModelBinding for StatefulWidget
/// - [ViewModelBindingPauseProvider]: Interface for pause/resume providers
mixin class ViewModelBinding
    implements
        ViewModelBindingInterface,
        ViewModelBindingRecreateCapability,
        ViewModelBindingStateSelectEqualsCapability {
  late final String _id = "${getName()}#${identityHashCode(this)}";

  String get id => _id;

  @protected
  // ignore: avoid_returning_this
  ViewModelBinding get viewModelBinding => this;

  /// (Deprecated) Use [viewModelBinding] instead.
  @Deprecated('Use viewModelBinding instead.')
  @protected
  ViewModelBinding get vef => viewModelBinding;

  bool _dispose = false;
  final _stackPathLocator = StackPathLocator();

  late final PauseAwareController _pauseAwareController =
      createPauseController();

  bool get isDisposed => _dispose;

  late final _instanceController = AutoDisposeInstanceController(
    onRecreate: _handleInstanceChange,
    onInstanceDetached: _handleInstanceDetached,
    onInstanceRecreated: _handleInstanceRecreated,
    viewModelBinding: this,
  );
  final Map<ViewModel, Function()> _stateListeners = Map.identity();
  final _defaultViewModelKey = Object();
  final List<_BindingSubscription> _subscriptions = [];
  final Map<(Type, Object), Object> _factorySources = {};
  final Map<ViewModel, (Type, Object)> _factoryIdentities = Map.identity();

  void _handleInstanceChange() {
    onUpdate();
  }

  void _handleInstanceDetached(ViewModel viewModel) {
    _stateListeners.remove(viewModel)?.call();
    final subscriptions = _subscriptions
        .where((subscription) => subscription.isAttachedTo(viewModel))
        .toList(growable: false);
    for (final subscription in subscriptions) {
      subscription.dispose();
      _subscriptions.remove(subscription);
    }
    assert(() {
      final identity = _factoryIdentities.remove(viewModel);
      if (identity != null) {
        _factorySources.remove(identity);
      }
      return true;
    }());
  }

  void _handleInstanceRecreated(ViewModel previous, ViewModel current) {
    final removeWatchListener = _stateListeners.remove(previous);
    if (removeWatchListener != null) {
      removeWatchListener.call();
      _addListener(current);
    }
    for (final subscription in _subscriptions.where(
      (subscription) => subscription.isAttachedTo(previous),
    )) {
      subscription.moveTo(current);
    }
    assert(() {
      final identity = _factoryIdentities.remove(previous);
      if (identity != null) {
        _factoryIdentities[current] = identity;
      }
      return true;
    }());
  }

  void _addSubscription<VM extends ViewModel>(
    VM viewModel,
    Function() Function(VM viewModel) attach,
  ) {
    _subscriptions.add(
      _BindingSubscription(
        viewModel: viewModel,
        attach: (value) => attach(value as VM),
      ),
    );
  }

  /// Called when any watched ViewModel notifies changes.
  ///
  /// Override this method to respond to ViewModel state changes. For example,
  /// [WidgetViewModelBinding] overrides this to call `setState()` and trigger
  /// widget rebuilds.
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
      viewModelLog("${getName()} Resume with missed updates, updated");
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
    );
  }

  /// Returns true if the binder is currently paused.
  bool get isPaused => _pauseAwareController.isPaused;

  /// Generates a debug-friendly name for this ViewModel binding.
  ///
  /// This method creates a unique identifier that includes the file path, line
  /// number, and class name where the ViewModel is being bound. This
  /// information is useful for debugging and development tools.
  ///
  /// Returns an empty string in release mode for performance.
  ///
  /// Example output: `lib/pages/counter_page.dart:25  _CounterPageState`
  String getName() {
    if (!kDebugMode) return "$runtimeType";

    final pathInfo = _stackPathLocator.getCurrentObjectPath();
    return pathInfo.isNotEmpty ? "$pathInfo#$runtimeType" : "$runtimeType";
  }

  /// Force-recycles a ViewModel and removes it from cache for every owner.
  ///
  /// This method manually disposes a ViewModel instance and triggers owner
  /// updates. Do not use it as a routine recreation or cleanup mechanism.
  /// Call it only when you explicitly understand and accept that every owner
  /// of the shared instance will lose the old object at once.
  ///
  /// Parameters:
  /// - [vm]: The ViewModel instance to dispose and remove
  ///
  /// Example:
  /// ```dart
  /// UserViewModel get userVM => viewModelBinding.watch(fac);
  ///
  /// // Advanced escape hatch: userVM is disposed for every owner. Their next
  /// // getter evaluation resolves a newly created instance.
  /// viewModelBinding.recycle(userVM);
  /// ```
  /// Warning: this is a destructive global operation for a shared instance.
  /// It removes all owners and also disposes `aliveForever` instances. It is
  /// an escape hatch, not the normal way to release the current binding.
  /// Consumers must use getter-based resolution; a stored field would keep
  /// pointing at the disposed object instead of resolving its replacement.
  @override
  void recycle<VM extends ViewModel>(VM vm) {
    _instanceController.recycle(vm);
    onUpdate();
  }

  @override
  VM recreate<VM extends ViewModel>(
    VM viewModel, {
    VM Function()? builder,
  }) {
    final owner = viewModel.refHandler.primaryOwner ?? viewModelBinding;
    return runWithBinding(
      () => _instanceController.recreate(viewModel, builder: builder),
      owner,
    );
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
  ///   MyViewModel get _viewModel =>
  ///       viewModelBinding.watch(MyViewModelSpec());
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
  ///   final vm = viewModelBinding.read(MyViewModelSpec());
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
  /// 常规业务代码应优先使用 [read] 或 [watch] 配合 spec 精确获取。明确的
  /// [key] 可唯一定位缓存；[tag] 可能对应多个实例，应使用 [readCachesByTag]
  /// 批量获取。若 [key]、[tag] 都不传，多实例场景会按创建顺序返回最新实例，
  /// 仅应在明确理解该行为时使用。
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

  List<VM> watchCachesByTag<VM extends ViewModel>(Object tag) {
    final res = _instanceController.getInstancesByTag<VM>(tag);
    for (final vm in res) {
      _addListener(vm);
    }
    return res;
  }

  List<VM> readCachesByTag<VM extends ViewModel>(Object tag) {
    return _instanceController.getInstancesByTag<VM>(tag);
  }

  VM _getViewModel<VM extends ViewModel>({
    ViewModelFactory<VM>? factory,
    InstanceArg arg = const InstanceArg(),
    bool listen = true,
  }) {
    // ensure getName call
    if (kDebugMode) {
      getName();
    }
    if (isDisposed) {
      throw ViewModelError("Cannot get $VM: "
          "ViewModelBinding(${getName()}) is already disposed.");
    }
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
      } on ViewModelError {
        // Expected: not found by key; fall through to factory or tag lookup.
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
    final res = runWithBinding(
      () {
        return _instanceController.getInstance<VM>(
          factory: InstanceFactory<VM>(
            arg: InstanceArg(
              key: key,
              tag: tag,
              aliveForever: factory.aliveForever(),
            ),
            builder: factory.build,
          ),
        )..refHandler.addRef(viewModelBinding);
      },
      viewModelBinding,
    );

    assert(() {
      _recordFactoryResolution<VM>(factory, key);
      _factoryIdentities[res] = (VM, key);
      return true;
    }());

    if (listen) {
      _addListener(res);
    }
    return res;
  }

  void _recordFactoryResolution<VM extends ViewModel>(
    ViewModelFactory<VM> factory,
    Object key,
  ) {
    assert(() {
      final identity = (VM, key);
      final source = factory.debugSource;
      final previous = _factorySources[identity];
      if (previous != null && !identical(previous, source)) {
        debugPrint(
          'view_model warning: Different factory sources resolved the same '
          '$VM + key ${Error.safeToString(key)} in binding $id. The cached '
          'instance is reused and the later builder will not run. Give each '
          'spec an explicit, distinct key.',
        );
      }
      _factorySources.putIfAbsent(identity, () => source);
      return true;
    }());
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
    if (!_stateListeners.containsKey(res)) {
      _stateListeners[res] = res.listen(onChanged: () {
        if (_dispose) return;
        // When paused, ignore updates; we'll blindly refresh on resume.
        if (_pauseAwareController.isPaused) {
          _hasMissedUpdates = true;
          viewModelLog(
            "${getName()} is paused, delay rebuild",
          );
          return;
        }
        onUpdate();
      });
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
  /// final vm = viewModelBinding.maybeWatchCached<MyViewModel>(
  ///   key: 'optional-key',
  /// );
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
    } on ViewModelError {
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

  void addPauseProvider(ViewModelBindingPauseProvider provider) {
    _pauseAwareController.addProvider(provider);
  }

  void removePauseProvider(ViewModelBindingPauseProvider provider) {
    _pauseAwareController.removeProvider(provider);
  }

  @mustCallSuper
  void dispose() {
    if (_dispose) return;
    _dispose = true;
    for (final removeListener in _stateListeners.values.toList()) {
      try {
        removeListener.call();
      } catch (e, stack) {
        reportViewModelError(e, stack, ErrorType.dispose,
            'ViewModelBinding watch listener dispose error');
      }
    }
    _stateListeners.clear();
    _factorySources.clear();
    _factoryIdentities.clear();
    // Run listener cleanup callbacks before disposing the instance controller,
    // to avoid listener callbacks firing during the disposal cascade.
    for (final subscription in _subscriptions.toList(growable: false)) {
      try {
        subscription.dispose();
      } catch (e, stack) {
        reportViewModelError(e, stack, ErrorType.dispose,
            'ViewModelBinding dispose listener error');
      }
    }
    _subscriptions.clear();
    try {
      _pauseAwareController.dispose();
    } catch (e, stack) {
      reportViewModelError(e, stack, ErrorType.dispose,
          'ViewModelBinding pauseController dispose error');
    }
    try {
      _instanceController.dispose();
    } catch (e, stack) {
      reportViewModelError(e, stack, ErrorType.dispose,
          'ViewModelBinding instanceController dispose error');
    }
  }

  @override
  void listen<VM extends ViewModel>(
    ViewModelFactory<VM> factory, {
    required VoidCallback onChanged,
  }) {
    final vm = viewModelBinding.read(factory);
    _addSubscription(vm, (value) => value.listen(onChanged: onChanged));
  }

  @override
  void listenState<VM extends StateViewModel<S>, S>(
    ViewModelFactory<VM> factory, {
    required Function(S? previous, S state) onChanged,
  }) {
    final VM vm = viewModelBinding.read<VM>(factory);
    _addSubscription(vm, (value) => value.listenState(onChanged: onChanged));
  }

  @override
  void listenStateSelect<VM extends StateViewModel<S>, S, R>(
    ViewModelFactory<VM> factory, {
    required R Function(S state) selector,
    required Function(R? previous, R current) onChanged,
  }) {
    final VM vm = viewModelBinding.read<VM>(factory);
    _addSubscription(
      vm,
      (value) => value.listenStateSelect(
        onChanged: onChanged,
        selector: selector,
      ),
    );
  }

  @override
  void listenStateSelectWithEquals<VM extends StateViewModel<S>, S, R>(
    ViewModelFactory<VM> factory, {
    required R Function(S state) selector,
    required bool Function(R previous, R current) equals,
    required Function(R? previous, R current) onChanged,
  }) {
    final VM vm = viewModelBinding.read<VM>(factory);
    _addSubscription(
      vm,
      (value) => value.listenStateSelectWithEquals(
        onChanged: onChanged,
        selector: selector,
        equals: equals,
      ),
    );
  }

  /// 安全查询已有缓存，未找到时返回 `null`。
  ///
  /// 常规业务代码应优先使用 [read] 或 [watch] 配合 spec 精确获取。明确的
  /// [key] 可唯一定位缓存；[tag] 多结果请使用 [readCachesByTag]。若 [key]、
  /// [tag] 都不传，多实例场景会依赖创建顺序返回最新实例，仅应在明确理解该
  /// 行为时使用。
  @override
  VM? maybeReadCached<VM extends ViewModel>({Object? key, Object? tag}) {
    try {
      return readCached(key: key, tag: tag);
    } on ViewModelError {
      // Expected: ViewModel not found in cache, return null as documented.
      return null;
    }
  }
}

extension ViewModelBindingHostExtension on ViewModelBindingHost {
  VM watchViewModel<VM extends ViewModel>(
      {required ViewModelFactory<VM> factory}) {
    return viewModelBinding.watch<VM>(factory);
  }

  void listenViewModel<VM extends ViewModel>({
    required ViewModelFactory<VM> factory,
    required VoidCallback onChanged,
  }) {
    viewModelBinding.listen<VM>(factory, onChanged: onChanged);
  }

  void listenViewModelState<VM extends StateViewModel<S>, S>({
    required ViewModelFactory<VM> factory,
    required Function(S? previous, S state) onChanged,
  }) {
    viewModelBinding.listenState<VM, S>(factory, onChanged: onChanged);
  }

  void listenViewModelStateSelect<VM extends StateViewModel<S>, S, R>({
    required ViewModelFactory<VM> factory,
    required R Function(S state) selector,
    required Function(R? previous, R current) onChanged,
  }) {
    viewModelBinding.listenStateSelect<VM, S, R>(
      factory,
      selector: selector,
      onChanged: onChanged,
    );
  }

  void
      listenViewModelStateSelectWithEquals<VM extends StateViewModel<S>, S, R>({
    required ViewModelFactory<VM> factory,
    required R Function(S state) selector,
    required bool Function(R previous, R current) equals,
    required Function(R? previous, R current) onChanged,
  }) {
    viewModelBinding.listenStateSelectWithEquals<VM, S, R>(
      factory,
      selector: selector,
      equals: equals,
      onChanged: onChanged,
    );
  }

  /// [ViewModelBindingInterface.recycle] 的兼容便捷入口。
  ///
  /// 这是危险的全局强制回收操作：会解除目标实例的全部 owners 并立即
  /// dispose，即使该实例设置了 `aliveForever`。一般不鼓励调用；只有明确
  /// 知道所有共享使用方都会受到影响时才应使用。
  ///
  /// recycle 后传入的旧实例已经 dispose。所有使用方都必须通过 getter
  /// 被动获取 ViewModel，并在每次访问时重新调用 `watch`/`read`；这样下一次
  /// 访问才能走正常的缓存未命中与实例创建流程。不要把 ViewModel 长期保存在
  /// `late final`、`final` 等字段中，否则字段会继续引用已销毁对象，可能造成
  /// 内存泄漏或其他异常。
  void recycleViewModel<VM extends ViewModel>(VM viewModel) {
    viewModelBinding.recycle<VM>(viewModel);
  }

  VM recreateViewModel<VM extends ViewModel>(
    VM viewModel, {
    VM Function()? builder,
  }) {
    return viewModelBinding.recreate<VM>(viewModel, builder: builder);
  }

  VM readViewModel<VM extends ViewModel>(
      {required ViewModelFactory<VM> factory}) {
    return viewModelBinding.read<VM>(factory);
  }

  /// 查询已有缓存但不监听变化。
  ///
  /// 常规业务代码应优先使用 `readViewModel` / `watchViewModel` 配合 spec
  /// 精确获取。明确的 [key] 可唯一定位缓存；[tag] 可能对应多个实例，应使用
  /// `viewModelBinding.readCachesByTag`。若 [key]、[tag] 都不传，多实例场景会
  /// 按创建顺序返回最新实例，仅应在明确理解该行为时使用。
  VM readCachedViewModel<VM extends ViewModel>({
    Object? key,
    Object? tag,
  }) {
    return viewModelBinding.readCached<VM>(
      key: key,
      tag: tag,
    );
  }

  VM watchCachedViewModel<VM extends ViewModel>({
    Object? key,
    Object? tag,
  }) {
    return viewModelBinding.watchCached<VM>(
      key: key,
      tag: tag,
    );
  }

  VM? maybeWatchCachedViewModel<VM extends ViewModel>({
    Object? key,
    Object? tag,
  }) {
    return viewModelBinding.maybeWatchCached<VM>(
      key: key,
      tag: tag,
    );
  }

  /// 安全查询已有缓存，未找到时返回 `null`。
  ///
  /// 常规业务代码应优先使用 `readViewModel` / `watchViewModel` 配合 spec
  /// 精确获取。明确的 [key] 可唯一定位缓存；[tag] 多结果请使用
  /// `viewModelBinding.readCachesByTag`。若 [key]、[tag] 都不传，多实例场景会
  /// 依赖创建顺序返回最新实例，仅应在明确理解该行为时使用。
  VM? maybeReadCachedViewModel<VM extends ViewModel>({
    Object? key,
    Object? tag,
  }) {
    return viewModelBinding.maybeReadCached<VM>(
      key: key,
      tag: tag,
    );
  }
}

/// (Deprecated) Use [ViewModelBinding] instead.
@Deprecated('Use ViewModelBinding instead.')
class Vef with ViewModelBinding {}
