import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:view_model/src/view_model/pause_aware.dart';
import 'package:view_model/src/view_model/pause_provider.dart';
import 'package:view_model/src/view_model/widget_mixin/view_model_binding.dart';

/// Stateless integration for ViewModel access from widgets.
///
/// Provides a mixin and a custom Element that bridge ViewModel
/// changes to StatelessWidget rebuilds. Supports watching and
/// reading ViewModels with or without listening.
///
/// > **Warning**: This mixin intercepts Element lifecycle and may conflict
/// > with other mixins. Prefer StatefulWidget with [ViewModelStateMixin].
///
/// > **Limitation**: Due to Flutter's @immutable constraint on StatelessWidget,
/// > each widget instance creates exactly one Element. If the same widget
/// > instance is mounted multiple times (e.g., via GlobalKey migration),
/// > behavior may be unexpected. For complex use cases, use StatefulWidget.
mixin ViewModelStatelessMixin on StatelessWidget {
  /// The cached element for this widget.
  ///
  /// Using late final ensures consistent element-to-widget binding.
  /// Note: This means a widget instance should not be mounted multiple times.
  late final _StatelessViewModelElement _viewModelElement =
      _StatelessViewModelElement(this);

  /// Returns true if the widget is currently considered paused.
  ///
  /// This state is determined by the [PauseAwareController] and its registered
  /// [ViewModelBindingPauseProvider]s. When paused,
  /// ViewModel updates are suppressed.
  bool get isPaused => _viewModelElement._binding.isPaused;

  @protected
  WidgetViewModelBinding get viewModelBinding => _viewModelElement._binding;

  /// (Deprecated) Use [viewModelBinding] instead.
  @Deprecated('Use viewModelBinding instead.')
  @protected
  WidgetViewModelBinding get vef => viewModelBinding;

  /// Creates the custom Element that bridges ViewModel updates.
  ///
  /// The Element owns `WidgetViewModelBinding` and connects its refresh to
  /// `markNeedsBuild` for this widget.
  @override
  StatelessElement createElement() => _viewModelElement;

  @visibleForTesting
  String getViewModelBindingName() => _viewModelElement._binding.getName();
}

/// Custom Element for `ViewModelStatelessMixin`.
/// Owns `WidgetViewModelBinding` and binds its rebuild callback to
/// `markNeedsBuild`. Manages attach and dispose with element
/// lifecycle.
class _StatelessViewModelElement extends StatelessElement {
  late final WidgetViewModelBinding _binding = WidgetViewModelBinding(
    refreshWidget: _rebuildState,
  );

  late final _appPauseProvider = AppPauseProvider();

  _StatelessViewModelElement(super.widget);

  /// Attaches the element and starts ViewModel listening.
  @override
  void mount(Element? parent, dynamic newSlot) {
    super.mount(parent, newSlot);
    _binding.init();
    _binding.addPauseProvider(_appPauseProvider);
  }

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
    _binding.dispose();
    _appPauseProvider.dispose();
  }
}
