import 'package:view_model/src/view_model/vef.dart';

/// A specialized Vef implementation for Flutter Widgets.
///
/// This class extends the base [Vef] functionality to integrate with
/// Flutter's widget lifecycle. It bridges ViewModel state changes to widget
/// rebuilds by calling the provided [refreshWidget] callback.
///
/// The [WidgetVef] is used internally by [ViewModelStateMixin] and
/// [ViewModelStatelessMixin] to manage ViewModel lifecycles within widgets.
///
/// Key responsibilities:
/// - Triggers widget rebuilds when ViewModels notify changes via [onUpdate]
/// - Handles pause/resume lifecycle inherited from [Vef]
/// - Manages ViewModel disposal when the widget is disposed
///
/// Example usage (typically handled internally by mixins):
/// ```dart
/// final vef.= WidgetVef(
///   refreshWidget: () => setState(() {}),
/// );
/// ```
class WidgetVef with Vef {
  /// Callback function to trigger widget rebuild.
  ///
  /// This is typically a reference to the widget's `setState` method or
  /// equivalent rebuild mechanism.
  final Function() refreshWidget;

  WidgetVef({
    required this.refreshWidget,
  });

  @override
  void onUpdate() {
    super.onUpdate();
    refreshWidget();
  }
}
