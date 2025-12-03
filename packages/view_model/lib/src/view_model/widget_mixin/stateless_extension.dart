import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:view_model/src/view_model/pause_aware.dart';
import 'package:view_model/src/view_model/pause_provider.dart';
import 'package:view_model/src/view_model/vef.dart';
import 'package:view_model/src/view_model/widget_mixin/vef.dart';

/// Stateless integration for ViewModel access from widgets.
/// Provides a mixin and a custom Element that bridge ViewModel
/// changes to StatelessWidget rebuilds. Supports watching and
/// reading ViewModels with or without listening.
mixin ViewModelStatelessMixin on StatelessWidget {
  late final _StatelessViewModelElement _viewModelElement =
      _StatelessViewModelElement(
    this,
  );

  /// Returns true if the widget is currently considered paused.
  ///
  /// This state is determined by the [PauseAwareController] and its registered
  /// [VefPauseProvider]s. When paused, ViewModel updates are suppressed.
  bool get isPaused => _viewModelElement._vef.isPaused;

  @protected
  Vef get vef => _viewModelElement._vef;

  /// Creates the custom Element that bridges ViewModel updates.
  /// The Element owns `WidgetVef` and connects its refresh to
  /// `markNeedsBuild` for this widget.
  @override
  StatelessElement createElement() {
    return _viewModelElement;
  }

  @visibleForTesting
  String getVefName() {
    return _viewModelElement._vef.getName();
  }
}

/// Custom Element for `ViewModelStatelessMixin`.
/// Owns `WidgetVef` and binds its rebuild callback to
/// `markNeedsBuild`. Manages attach and dispose with element
/// lifecycle.
class _StatelessViewModelElement extends StatelessElement {
  late final WidgetVef _vef = WidgetVef(
    refreshWidget: _rebuildState,
  );

  late final _appPauseProvider = AppPauseProvider();

  _StatelessViewModelElement(super.widget);

  /// Attaches the element and starts ViewModel listening.
  @override
  void mount(Element? parent, dynamic newSlot) {
    super.mount(parent, newSlot);
    _vef.init();
    _vef.addPauseProvider(_appPauseProvider);
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
    _vef.dispose();
    _appPauseProvider.dispose();
  }
}
