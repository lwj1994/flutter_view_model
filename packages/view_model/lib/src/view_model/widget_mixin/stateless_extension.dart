import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:view_model/src/view_model/pause_aware.dart';
import 'package:view_model/src/view_model/pause_provider.dart';
import 'package:view_model/src/view_model/view_model_binding.dart';
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
/// > **Limitation**: Each widget instance can refer to only one Element. Do not
/// > mount the same widget instance in multiple locations simultaneously.
/// > Ordinary parent rebuilds reuse the existing Element and its binding.
mixin ViewModelStatelessMixin on StatelessWidget
    implements ViewModelBindingHost {
  // The final holder lets replacement widgets adopt the mounted Element without
  // introducing mutable fields on the immutable Widget configuration.
  final _elementReference = _ViewModelElementReference();

  _StatelessViewModelElement get _viewModelElement =>
      _elementReference.element ??= _StatelessViewModelElement(this);

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

class _ViewModelElementReference {
  _StatelessViewModelElement? element;
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

  @override
  void update(covariant StatelessWidget newWidget) {
    // StatelessElement.update immediately rebuilds with the new Widget, so its
    // context-free binding accessor must already refer to this mounted Element.
    (newWidget as ViewModelStatelessMixin)._elementReference.element = this;
    super.update(newWidget);
  }

  void _rebuildState() {
    if (!mounted) return;
    if (SchedulerBinding.instance.schedulerPhase !=
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
