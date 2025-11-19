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
import 'package:view_model/src/view_model/extension/attacher.dart';
import 'package:view_model/src/view_model/interface.dart';
import 'package:view_model/src/view_model/pause_provider.dart';
import 'package:view_model/src/view_model/pause_aware.dart';
import 'package:view_model/src/view_model/util.dart';
import 'package:view_model/src/view_model/view_model.dart';

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
mixin ViewModelStateMixin<T extends StatefulWidget> on State<T>
    implements ViewModelCreateInterface {
  @visibleForTesting
  late final ViewModelAttacher attacher = ViewModelAttacher(
    rebuildState: _rebuildState,
    getBinderName: getViewModelBinderName,
    pauseAwareController: _pauseAwareController,
  );

  final List<ViewModelPauseProvider> _viewModelPauseProviders = [];

  void addViewModelPauseProvider(ViewModelPauseProvider provider) {
    _viewModelPauseProviders.add(provider);
  }

  void removeViewModelPauseProvider(ViewModelPauseProvider provider) {
    _viewModelPauseProviders.remove(provider);
  }

  late final _routePauseProvider = PageRoutePauseProvider(
    binderName: getViewModelBinderName(),
  );

  /// A fallback for pageRouteAware is implemented here.
  late final _pauseAwareController = PauseAwareController(
    onWidgetPause: _onPause,
    onWidgetResume: _onResume,
    providers: [
      ViewModelManualPauseProvider(),
      AppPauseLifecycleProvider(),
      _routePauseProvider,
      ..._viewModelPauseProviders,
    ],
    binderName: getViewModelBinderName(),
  );

  final _stackPathLocator = StackPathLocator();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      _routePauseProvider.subscribe(route);
    }
  }

  @override
  VM watchViewModel<VM extends ViewModel>({
    required ViewModelFactory<VM> factory,
  }) {
    return attacher.watchViewModel(
      factory: factory,
    );
  }

  @override
  void recycleViewModel<VM extends ViewModel>(VM viewModel) {
    attacher.recycleViewModel(viewModel);
  }

  @override
  VM watchCachedViewModel<VM extends ViewModel>({Object? key, Object? tag}) {
    return attacher.watchCachedViewModel(
      key: key,
      tag: tag,
    );
  }

  @override
  VM? maybeWatchCachedViewModel<VM extends ViewModel>({
    Object? key,
    Object? tag,
  }) {
    return attacher.maybeWatchCachedViewModel(
      key: key,
      tag: tag,
    );
  }

  @override
  VM readViewModel<VM extends ViewModel>({
    required ViewModelFactory<VM> factory,
  }) {
    return attacher.readViewModel(
      factory: factory,
    );
  }

  @override
  VM readCachedViewModel<VM extends ViewModel>({Object? key, Object? tag}) {
    return attacher.readCachedViewModel(
      key: key,
      tag: tag,
    );
  }

  @override
  VM? maybeReadCachedViewModel<VM extends ViewModel>({
    Object? key,
    Object? tag,
  }) {
    return attacher.maybeReadCachedViewModel(
      key: key,
      tag: tag,
    );
  }

  @override
  void initState() {
    super.initState();
    attacher.attach();
  }

  @override
  void dispose() {
    super.dispose();
    attacher.dispose();
    _pauseAwareController.dispose();
    _viewModelPauseProviders.clear();
  }

  void _rebuildState() {
    if (attacher.isDisposed) return;
    if (context.mounted &&
        SchedulerBinding.instance.schedulerPhase !=
            SchedulerPhase.persistentCallbacks) {
      setState(() {});
    } else {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!attacher.isDisposed && context.mounted) {
          setState(() {});
        }
      });
    }
  }

  /// Generates a debug-friendly name for this ViewModel watcher.
  ///
  /// This method creates a unique identifier that includes the file path,
  /// line number, and class name where the ViewModel is being watched.
  /// This information is useful for debugging and development tools.
  ///
  /// Returns an empty string in release mode for performance.
  ///
  /// Example output: `lib/pages/counter_page.dart:25  _CounterPageState`
  String getViewModelBinderName() {
    if (!kDebugMode) return "$runtimeType";

    final pathInfo = _stackPathLocator.getCurrentObjectPath();
    return pathInfo.isNotEmpty ? "$pathInfo#$runtimeType" : "$runtimeType";
  }

  void _onResume() {
    // ignore: invalid_use_of_protected_member
    attacher.performForAllViewModels((viewModel) => viewModel.onResume(this));
    _rebuildState();
  }

  void _onPause() {
    // ignore: invalid_use_of_protected_member
    attacher.performForAllViewModels((viewModel) => viewModel.onPause(this));
  }
}
