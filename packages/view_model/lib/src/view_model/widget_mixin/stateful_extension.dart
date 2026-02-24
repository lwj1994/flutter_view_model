library;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:view_model/src/view_model/pause_provider.dart';
import 'package:view_model/src/view_model/widget_mixin/view_model_binding.dart';
import 'package:view_model/view_model.dart';

/// Mixin that integrates ViewModels with Flutter's State lifecycle.
///
/// This mixin provides methods to watch and read ViewModels from within a
/// StatefulWidget's State. It automatically handles:
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
///     viewModel = viewModelBinding.watch(
///       MyViewModelSpec(),
///     );
///   }
///
///   @override
///   Widget build(BuildContext context) {
///     return Text('Count: ${viewModel.count}');
///   }
/// }
/// ```
mixin ViewModelStateMixin<T extends StatefulWidget> on State<T> {
  @protected
  late final WidgetViewModelBinding viewModelBinding = WidgetViewModelBinding(
    refreshWidget: _rebuildState,
  );

  /// (Deprecated) Use [viewModelBinding] instead.
  @Deprecated('Use viewModelBinding instead.')
  @protected
  WidgetViewModelBinding get vef => viewModelBinding;

  late final _routePauseProvider = PageRoutePauseProvider();
  late final TickerModePauseProvider _tickerModePauseProvider =
      TickerModePauseProvider();
  late final _appPauseProvider = AppPauseProvider();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ignore: deprecated_member_use
    _tickerModePauseProvider.subscribe(TickerMode.getNotifier(context));
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      _routePauseProvider.subscribe(route);
    }
  }

  bool get isPaused => viewModelBinding.isPaused;

  @override
  void initState() {
    super.initState();
    viewModelBinding.init();
    viewModelBinding.addPauseProvider(_appPauseProvider);
    viewModelBinding.addPauseProvider(_routePauseProvider);
    viewModelBinding.addPauseProvider(_tickerModePauseProvider);
  }

  @override
  void dispose() {
    super.dispose();
    viewModelBinding.dispose();
    _appPauseProvider.dispose();
    _routePauseProvider.dispose();
    _tickerModePauseProvider.dispose();
  }

  void _rebuildState() {
    if (viewModelBinding.isDisposed) return;
    if (context.mounted &&
        SchedulerBinding.instance.schedulerPhase !=
            SchedulerPhase.persistentCallbacks) {
      setState(() {});
    } else {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!viewModelBinding.isDisposed && context.mounted) {
          setState(() {});
        }
      });
    }
  }
}
