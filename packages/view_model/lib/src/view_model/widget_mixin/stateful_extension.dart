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

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:view_model/view_model.dart';

import 'refer.dart';

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
  @protected
  late final WidgetRefer refer = WidgetRefer(
    refreshWidget: _rebuildState,
  );

  late final _routePauseProvider = PageRoutePauseProvider();
  late final TickerModePauseProvider _tickerModePauseProvider =
      TickerModePauseProvider();
  late final _appPauseProvider = AppPauseProvider();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tickerModePauseProvider.subscribe(TickerMode.getNotifier(context));
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      _routePauseProvider.subscribe(route);
    }
  }

  bool get isPaused => refer.isPaused;

  @override
  void initState() {
    super.initState();
    refer.init();
    refer.addPauseProvider(_appPauseProvider);
    refer.addPauseProvider(_routePauseProvider);
    refer.addPauseProvider(_tickerModePauseProvider);
  }

  @override
  void dispose() {
    super.dispose();
    refer.dispose();
    _appPauseProvider.dispose();
    _routePauseProvider.dispose();
    _tickerModePauseProvider.dispose();
  }

  void _rebuildState() {
    if (refer.isDisposed) return;
    if (context.mounted &&
        SchedulerBinding.instance.schedulerPhase !=
            SchedulerPhase.persistentCallbacks) {
      setState(() {});
    } else {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!refer.isDisposed && context.mounted) {
          setState(() {});
        }
      });
    }
  }

  String getWidgetBinderName() {
    return refer.getBinderName();
  }
}
