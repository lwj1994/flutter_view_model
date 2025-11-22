import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:view_model/src/log.dart';
import 'package:view_model/src/view_model/extension/attacher.dart';
import 'package:view_model/src/view_model/interface.dart';
import 'package:view_model/src/view_model/pause_aware.dart';
import 'package:view_model/src/view_model/pause_provider.dart';
import 'package:view_model/src/view_model/util.dart';
import 'package:view_model/src/view_model/view_model.dart';

/// Stateless integration for ViewModel access from widgets.
/// Provides a mixin and a custom Element that bridge ViewModel
/// changes to StatelessWidget rebuilds. Supports watching and
/// reading ViewModels with or without listening.
mixin ViewModelStatelessMixin on StatelessWidget
    implements ViewModelCreateInterface {
  late final _StatelessViewModelElement _viewModelElement =
      _StatelessViewModelElement(
    this,
    getViewModelBinderName: getViewModelBinderName,
  );
  final _stackPathLocator = StackPathLocator();

  /// Returns true if the widget is currently considered paused.
  ///
  /// This state is determined by the [PauseAwareController] and its registered
  /// [ViewModelPauseProvider]s. When paused, ViewModel updates are suppressed.
  bool get isPaused => _viewModelElement._pauseAwareController.isPaused;

  void addViewModelPauseProvider(ViewModelPauseProvider provider) {
    _viewModelElement._pauseAwareController.addProvider(provider);
  }

  void removeViewModelPauseProvider(ViewModelPauseProvider provider) {
    _viewModelElement._pauseAwareController.removeProvider(provider);
  }

  /// Creates the custom Element that carries the attacher.
  /// The Element owns the `ViewModelAttacher` and connects
  /// ViewModel notifications to `markNeedsBuild` for this
  /// widget.
  @override
  StatelessElement createElement() {
    return _viewModelElement;
  }

  /// Watches a cached ViewModel and rebuilds when it changes.
  /// Finds by `key` or `tag`. Does not create new instances.
  @override
  VM watchCachedViewModel<VM extends ViewModel>({Object? key, Object? tag}) {
    return _viewModelElement._attacher.watchCachedViewModel(
      key: key,
      tag: tag,
    );
  }

  /// Creates or fetches a ViewModel and listens for changes.
  @override
  VM watchViewModel<VM extends ViewModel>(
      {required ViewModelFactory<VM> factory}) {
    return _viewModelElement._attacher.watchViewModel(
      factory: factory,
    );
  }

  @override
  void recycleViewModel<VM extends ViewModel>(VM viewModel) {
    _viewModelElement._attacher.recycleViewModel(viewModel);
  }

  /// Safe watch for cached ViewModel, returns `null` when not found.
  @override
  VM? maybeWatchCachedViewModel<VM extends ViewModel>(
      {Object? key, Object? tag}) {
    return _viewModelElement._attacher.maybeWatchCachedViewModel(
      key: key,
      tag: tag,
    );
  }

  /// Safe read for cached ViewModel, returns `null` when not found.
  @override
  VM? maybeReadCachedViewModel<VM extends ViewModel>(
      {Object? key, Object? tag}) {
    return _viewModelElement._attacher.maybeReadCachedViewModel(
      key: key,
      tag: tag,
    );
  }

  /// Reads a cached ViewModel without listening for changes.
  @override
  VM readCachedViewModel<VM extends ViewModel>({Object? key, Object? tag}) {
    return _viewModelElement._attacher.readCachedViewModel(
      key: key,
      tag: tag,
    );
  }

  /// Creates or fetches a ViewModel without listening for changes.
  @override
  VM readViewModel<VM extends ViewModel>(
      {required ViewModelFactory<VM> factory}) {
    return _viewModelElement._attacher.readViewModel(
      factory: factory,
    );
  }

  String getViewModelBinderName() {
    if (!kDebugMode) return "";

    final pathInfo = _stackPathLocator.getCurrentObjectPath();
    return pathInfo.isNotEmpty ? "$pathInfo#$runtimeType" : "$runtimeType";
  }
}

/// Custom Element for `ViewModelStatelessMixin`.
/// Owns the `ViewModelAttacher` and binds its rebuild callback
/// to `markNeedsBuild`. Manages attach and dispose with element
/// lifecycle.
class _StatelessViewModelElement extends StatelessElement {
  final String Function() getViewModelBinderName;
  late final ViewModelAttacher _attacher = ViewModelAttacher(
    rebuildState: _rebuildState,
    getBinderName: getViewModelBinderName,
    pauseAwareController: _pauseAwareController,
  );

  late final _appPauseProvider = AppPauseProvider();

  late final _pauseAwareController = PauseAwareController(
      onWidgetPause: _onPause,
      onWidgetResume: _onResume,
      providers: [
        _appPauseProvider,
      ],
      disposableProviders: [
        _appPauseProvider,
      ],
      binderName: getViewModelBinderName);

  _StatelessViewModelElement(super.widget,
      {required this.getViewModelBinderName});

  /// Attaches the element and starts ViewModel listening.
  @override
  void mount(Element? parent, dynamic newSlot) {
    _attacher.attach();
    super.mount(parent, newSlot);
  }

  void _onResume() {
    if (_attacher.hasMissedUpdates) {
      viewModelLog(
          "${getViewModelBinderName()} Resume with missed updates, rebuilding");
      _attacher.consumeMissedUpdates();
      _rebuildState();
    }
  }

  void _onPause() {}

  void _rebuildState() {
    if (!mounted) return;
    if (mounted &&
        SchedulerBinding.instance.schedulerPhase !=
            SchedulerPhase.persistentCallbacks) {
      markNeedsBuild();
    } else {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          markNeedsBuild();
        }
      });
    }
  }

  /// Disposes ViewModel listeners when the element is removed.
  @override
  void unmount() {
    super.unmount();
    _attacher.dispose();
    _pauseAwareController.dispose();
  }
}
